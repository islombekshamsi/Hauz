import { loadSync } from "https://deno.land/std@0.203.0/dotenv/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

let localEnv: Record<string, string> = {};
const rootEnvPath = new URL("../../../.env", import.meta.url).pathname;
try {
  localEnv = loadSync({ envPath: rootEnvPath });
} catch {
  // ignore
}

const getEnv = (key: string, aliases: string[] = []) => {
  const keys = [key, ...aliases];
  for (const candidate of keys) {
    const value = Deno.env.get(candidate) ?? localEnv[candidate];
    if (value) return value;
  }
  return undefined;
};

const SUPABASE_URL = getEnv("SUPABASE_URL", ["EDGE_SUPABASE_URL"])!;
const SUPABASE_SERVICE_ROLE_KEY = getEnv("SUPABASE_SERVICE_ROLE_KEY", ["EDGE_SUPABASE_SERVICE_ROLE_KEY"])!;
const KICKSDB_API_KEY = getEnv("KICKSDB_API_KEY", ["EDGE_KICKSDB_API_KEY"])!;
const SYNC_SECRET = getEnv("SYNC_SECRET", ["EDGE_SYNC_SECRET"]);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const STOCKX_PRICES_ENDPOINT = "https://api.kicks.dev/v3/stockx/prices";

type StockxPricesVariant = {
  size: string;
  size_type: string;
  price: number;
};

type StockxPricesOutput = {
  product_id: string;
  variants: StockxPricesVariant[] | null;
};

const parseBool = (value: string | null, fallback: boolean) => {
  if (value === null) return fallback;
  const v = value.toLowerCase().trim();
  if (["1", "true", "yes", "y", "on"].includes(v)) return true;
  if (["0", "false", "no", "n", "off"].includes(v)) return false;
  return fallback;
};

const parseIntParam = (value: string | null, fallback: number, max?: number) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return fallback;
  const i = Math.trunc(n);
  if (typeof max === "number") return Math.min(i, max);
  return i;
};

const normalizeSizeKey = (_sizeType?: string | null, size?: string | null) =>
  (size ?? "").toLowerCase().trim();

async function fetchStockxPricesBatch(productIds: string[], market: string) {
  if (!productIds.length) return { data: [] as StockxPricesOutput[], status: 0 };

  const response = await fetch(STOCKX_PRICES_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${KICKSDB_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      market,
      product_ids: productIds
    })
  });

  const raw = await response.text();
  if (!response.ok) {
    console.warn("StockX prices request failed", response.status, raw);
    return { data: [] as StockxPricesOutput[], status: response.status };
  }

  const body = JSON.parse(raw);
  const data = Array.isArray(body?.data) ? body.data : [];
  return { data: (data as StockxPricesOutput[]), status: response.status };
}

Deno.serve(async (req) => {
  try {
    if (SYNC_SECRET) {
      const provided = req.headers.get("x-sync-secret");
      if (!provided || provided !== SYNC_SECRET) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
      }
    }

    const url = new URL(req.url);
    const offset = parseIntParam(url.searchParams.get("offset"), 0);
    const limit = parseIntParam(url.searchParams.get("limit"), 25, 50);
    const market = (url.searchParams.get("market") ?? "US").toUpperCase();
    const idsParam = url.searchParams.get("ids");
    const onlyIfMissing = parseBool(url.searchParams.get("onlyIfMissing"), true);
    const debug = parseBool(url.searchParams.get("debug"), false);

    let q = supabase
      .from("unified_sneakers")
      .select("id, sources_order, sources, prices_by_size")
      .order("updated_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (idsParam) {
      const ids = idsParam.split(",").map((s) => s.trim()).filter(Boolean);
      if (ids.length) {
        q = supabase
          .from("unified_sneakers")
          .select("id, sources_order, sources, prices_by_size")
          .in("id", ids);
      }
    }

    const { data: rows, error } = await q;
    if (error) throw new Error(error.message);

    const rowList = Array.isArray(rows) ? rows : [];
    const stockxIdxByRow = new Map<string, number>();
    const productIds: string[] = [];

    for (const r of rowList as any[]) {
      const order = Array.isArray(r.sources_order) ? r.sources_order : [];
      const idx = order.indexOf("stockx");
      if (idx === -1) continue;
      stockxIdxByRow.set(String(r.id), idx);

      const pid = r?.sources?.stockx?.product_id ?? r.id;
      if (pid) productIds.push(String(pid));
    }

    // Batch fetch (50 max)
    const pricesRes = await fetchStockxPricesBatch(productIds.slice(0, 50), market);
    const dictByProductId = new Map<string, Record<string, number>>();

    for (const p of pricesRes.data) {
      const dict: Record<string, number> = {};
      for (const v of p.variants ?? []) {
        const key = normalizeSizeKey(v.size_type, v.size);
        if (!key || typeof v.price !== "number") continue;
        dict[key] = typeof dict[key] === "number" ? Math.min(dict[key], v.price) : v.price;
      }
      dictByProductId.set(String(p.product_id), dict);
    }

    let applied = 0;
    for (const r of rowList as any[]) {
      const rowId = String(r.id);
      const order = Array.isArray(r.sources_order) ? r.sources_order : [];
      const stockxIdx = order.indexOf("stockx");
      if (stockxIdx === -1) continue;

      const pid = String(r?.sources?.stockx?.product_id ?? rowId);
      const stockxDict = dictByProductId.get(pid) ?? {};

      const oldPrices: Record<string, any> = (r.prices_by_size && typeof r.prices_by_size === "object") ? r.prices_by_size : {};
      const out: Record<string, (number | null)[]> = {};

      const keys = new Set<string>([...Object.keys(oldPrices), ...Object.keys(stockxDict)]);
      for (const sizeKey of keys) {
        const existing = oldPrices[sizeKey];
        const arr: (number | null)[] = Array.isArray(existing)
          ? [...existing].slice(0, order.length).map((x) => (typeof x === "number" ? x : null))
          : new Array(order.length).fill(null);

        while (arr.length < order.length) arr.push(null);

        const stockxPrice = stockxDict[sizeKey];
        if (typeof stockxPrice === "number") {
          if (!onlyIfMissing || arr[stockxIdx] === null) {
            arr[stockxIdx] = stockxPrice;
          }
        }
        out[sizeKey] = arr;
      }

      const { error: updErr } = await supabase
        .from("unified_sneakers")
        .update({ prices_by_size: out, updated_at: new Date() })
        .eq("id", rowId);
      if (updErr) throw new Error(updErr.message);
      applied += 1;
    }

    return new Response(JSON.stringify({ applied, market, ...(debug ? { stockxPricesStatus: pricesRes.status } : {}) }), { status: 200 });
  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

