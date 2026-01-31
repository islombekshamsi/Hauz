import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

function parseEnvFile(filePath) {
  const out = {};
  try {
    const content = fs.readFileSync(filePath, "utf8");
    for (const line of content.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq === -1) continue;
      const k = trimmed.slice(0, eq).trim();
      const v = trimmed.slice(eq + 1).trim();
      if (k) out[k] = v;
    }
  } catch {
    // ignore
  }
  return out;
}

function getArg(name, fallback) {
  const idx = process.argv.findIndex((a) => a === `--${name}`);
  if (idx === -1) return fallback;
  return process.argv[idx + 1] ?? fallback;
}

function toInt(v, fallback) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

function normalizeSizeKey(sizeType, size) {
  const t = String(sizeType ?? "").toLowerCase().trim().replace(/\s+/g, "_");
  const s = String(size ?? "").toLowerCase().trim().replace(/\s+/g, "_");
  return `${t}_${s}`; // e.g. us_m_10, us_w_11.5
}

async function fetchJson(url, opts) {
  const res = await fetch(url, opts);
  const txt = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}: ${txt}`);
  return txt ? JSON.parse(txt) : null;
}

async function fetchStockxPricesBatch({ apiKey, market, productIds }) {
  const body = await fetchJson("https://api.kicks.dev/v3/stockx/prices", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      market,
      product_ids: productIds,
    }),
  });

  return Array.isArray(body?.data) ? body.data : [];
}

async function main() {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  const keysEnvPath = path.resolve(__dirname, "../supabase/functions/keys.env");

  const fileEnv = parseEnvFile(keysEnvPath);
  const env = { ...fileEnv, ...process.env };

  const SUPABASE_URL = env.SUPABASE_URL || env.EDGE_SUPABASE_URL;
  const SUPABASE_SERVICE_ROLE_KEY =
    env.SUPABASE_SERVICE_ROLE_KEY || env.EDGE_SUPABASE_SERVICE_ROLE_KEY;
  const KICKSDB_API_KEY = env.KICKSDB_API_KEY || env.EDGE_KICKSDB_API_KEY;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !KICKSDB_API_KEY) {
    throw new Error("Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / KICKSDB_API_KEY");
  }

  const start = toInt(getArg("start", "0"), 0);
  const count = toInt(getArg("count", "1000"), 1000);
  const market = getArg("market", "US");

  const selectUrl = new URL(`${SUPABASE_URL}/rest/v1/shoe_sources`);
  selectUrl.searchParams.set("select", "shoe_id,source,source_product_id");
  selectUrl.searchParams.set("source", "eq.stockx");
  selectUrl.searchParams.set("order", "shoe_id.asc");
  selectUrl.searchParams.set("offset", String(start));
  selectUrl.searchParams.set("limit", String(count));

  const rows = await fetchJson(selectUrl.toString(), {
    headers: {
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      apikey: SUPABASE_SERVICE_ROLE_KEY,
    },
  });

  if (!Array.isArray(rows) || rows.length === 0) {
    console.log("No rows found for given range.");
    return;
  }

  console.log(`Loaded ${rows.length} stockx source rows (start=${start}, count=${count}).`);

  const BATCH = 50;
  let updated = 0;

  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH);
    const productIds = batch.map((r) => r.source_product_id);

    const prices = await fetchStockxPricesBatch({
      apiKey: KICKSDB_API_KEY,
      market,
      productIds,
    });

    const byProductId = new Map();
    for (const p of prices) {
      const dict = {};
      for (const v of p?.variants ?? []) {
        const key = normalizeSizeKey(v.size_type, v.size);
        const prev = dict[key];
        dict[key] = typeof prev === "number" ? Math.min(prev, v.price) : v.price;
      }
      byProductId.set(String(p.product_id), dict);
    }

    const payload = batch.map((r) => ({
      shoe_id: r.shoe_id,
      source: r.source,
      source_product_id: r.source_product_id,
      market,
      prices_by_size: byProductId.get(String(r.source_product_id)) ?? {},
      last_synced_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }));

    const upsertUrl = new URL(`${SUPABASE_URL}/rest/v1/shoe_sources`);
    upsertUrl.searchParams.set("on_conflict", "shoe_id,source");

    await fetchJson(upsertUrl.toString(), {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Prefer: "resolution=merge-duplicates,return=minimal",
      },
      body: JSON.stringify(payload),
    });

    updated += payload.length;
    if ((i / BATCH) % 10 === 0) {
      console.log(`Progress: updated ${updated}/${rows.length} rows...`);
    }
  }

  console.log(`Done. Updated ${updated} stockx rows with prices_by_size (market=${market}).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

