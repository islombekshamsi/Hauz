import { loadSync } from "https://deno.land/std@0.203.0/dotenv/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Optional: load repo .env in local dev
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

const GOAT_PRODUCTS_ENDPOINT = "https://api.kicks.dev/v3/goat/products";
const UNIFIED_PRODUCTS_ENDPOINT = "https://api.kicks.dev/v3/unified/products";

const MARKETPLACE_ORDER = [
  "stockx",
  "goat",
  "flight_club",
  "stadium_goods",
  "kickscrew",
  "shopify"
];

type UnifiedRow = {
  id: string;
  sku: string | null;
  slug: string | null;
  sources_order: string[];
  sources: Record<string, any> | null;
  prices_by_size: Record<string, number[] | null> | null;
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

const normalizeShopKey = (shopName: string) => {
  // Normalize to snake_case-ish keys (flight club -> flight_club)
  return shopName
    .toLowerCase()
    .trim()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
};

const recomputeSourcesOrder = (sources: Record<string, any>) => {
  const keys = Object.keys(sources);
  const preferred = MARKETPLACE_ORDER.filter((k) => keys.includes(k));
  const rest = keys.filter((k) => !preferred.includes(k)).sort();
  return [...preferred, ...rest];
};

const mergePricesBySize = (args: {
  oldOrder: string[];
  oldPricesBySize: Record<string, number[] | null>;
  newOrder: string[];
  patchBySource: Record<string, Record<string, number>>;
}) => {
  const { oldOrder, oldPricesBySize, newOrder, patchBySource } = args;
  const out: Record<string, (number | null)[]> = {};

  const sizeKeys = new Set<string>();
  for (const k of Object.keys(oldPricesBySize)) sizeKeys.add(k);
  for (const source of Object.keys(patchBySource)) {
    for (const k of Object.keys(patchBySource[source] ?? {})) sizeKeys.add(k);
  }

  for (const sizeKey of sizeKeys) {
    const arr: (number | null)[] = new Array(newOrder.length).fill(null);

    // carry forward old values by mapping source name -> index
    const oldArr = oldPricesBySize[sizeKey] ?? null;
    if (Array.isArray(oldArr)) {
      for (let i = 0; i < oldOrder.length; i++) {
        const src = oldOrder[i];
        const newIdx = newOrder.indexOf(src);
        if (newIdx === -1) continue;
        const val = oldArr[i];
        if (typeof val === "number") arr[newIdx] = val;
      }
    }

    // apply patches (e.g., goat size prices)
    for (const [src, dict] of Object.entries(patchBySource)) {
      const newIdx = newOrder.indexOf(src);
      if (newIdx === -1) continue;
      const val = dict?.[sizeKey];
      if (typeof val === "number") arr[newIdx] = val;
    }

    out[sizeKey] = arr;
  }

  return out;
};

async function fetchGoatMatchBySkuOrSlug(args: { sku?: string | null; slug?: string | null }) {
  const tryFetch = async (params: { sku?: string; slug?: string }) => {
    const url = new URL(GOAT_PRODUCTS_ENDPOINT);
    url.searchParams.set("limit", "1");
    url.searchParams.set("page", "1");
    url.searchParams.set("display[variants]", "true");

    if (params.sku) url.searchParams.set("sku", params.sku);
    if (params.slug) url.searchParams.set("slugs", params.slug);

    const response = await fetch(url, {
      headers: { "Authorization": `Bearer ${KICKSDB_API_KEY}` }
    });

    const raw = await response.text();
    if (!response.ok) {
      console.warn("GOAT lookup failed", response.status, raw);
      return { product: null as any, status: response.status, count: 0 };
    }

    const body = JSON.parse(raw);
    const data = Array.isArray(body?.data) ? body.data : [];
    return { product: (data[0] ?? null), status: response.status, count: data.length };
  };

  const sku = args.sku?.trim() ?? null;
  const slug = args.slug?.trim() ?? null;
  if (!sku && !slug) return { product: null as any, status: 0, count: 0 };

  if (sku) {
    const res1 = await tryFetch({ sku });
    if (res1.product) return res1;

    const skuSpace = sku.replace(/-/g, " ").replace(/\s+/g, " ").trim();
    if (skuSpace && skuSpace !== sku) {
      const res2 = await tryFetch({ sku: skuSpace });
      if (res2.product) return res2;
    }

    const skuNoDash = sku.replace(/-/g, "").trim();
    if (skuNoDash && skuNoDash !== sku && skuNoDash !== skuSpace) {
      const res3 = await tryFetch({ sku: skuNoDash });
      if (res3.product) return res3;
    }
  }

  if (slug) {
    return await tryFetch({ slug });
  }

  return { product: null as any, status: 200, count: 0 };
}

async function fetchUnifiedMatches(identifier: string, similarity: number) {
  const url = new URL(`${UNIFIED_PRODUCTS_ENDPOINT}/${encodeURIComponent(identifier)}`);
  url.searchParams.set("similarity", String(similarity));

  const response = await fetch(url, {
    headers: { "Authorization": `Bearer ${KICKSDB_API_KEY}` }
  });
  const raw = await response.text();
  if (!response.ok) {
    console.warn("Unified lookup failed", response.status, raw);
    return { matches: [] as any[], status: response.status };
  }

  const body = JSON.parse(raw);
  const data = Array.isArray(body?.data) ? body.data : [];
  return { matches: (data as any[]), status: response.status };
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
    const includeGoat = parseBool(url.searchParams.get("goat"), true);
    const includeUnified = parseBool(url.searchParams.get("unified"), true);
    const onlyIdentified = parseBool(url.searchParams.get("onlyIdentified"), true);
    const newestFirst = parseBool(url.searchParams.get("newestFirst"), true);
    const debug = parseBool(url.searchParams.get("debug"), false);
    const similarity = Number(url.searchParams.get("similarity") ?? "0.85");
    const safeSimilarity = Number.isFinite(similarity) ? Math.max(0, Math.min(1, similarity)) : 0.85;

    let q = supabase
      .from("unified_sneakers")
      .select("id, sku, slug, sources_order, sources, prices_by_size")
      .order(newestFirst ? "updated_at" : "id", { ascending: !newestFirst })
      .range(offset, offset + limit - 1);

    if (onlyIdentified) {
      q = q.or("sku.not.is.null,slug.not.is.null");
    }

    const { data: rows, error } = await q;
    if (error) throw new Error(error.message);

    const updates: { id: string; sources_order: string[]; sources: Record<string, any>; prices_by_size: Record<string, (number | null)[]> }[] = [];
    let goatAdded = 0;
    let unifiedAdded = 0;
    const goatStatusCounts: Record<string, number> = {};
    const unifiedStatusCounts: Record<string, number> = {};

    for (const row of (rows ?? []) as UnifiedRow[]) {
      const sources: Record<string, any> = (row.sources && typeof row.sources === "object") ? row.sources : {};
      const oldOrder = Array.isArray(row.sources_order) ? row.sources_order : [];
      const oldPrices = (row.prices_by_size && typeof row.prices_by_size === "object") ? row.prices_by_size : {};

      const patchBySource: Record<string, Record<string, number>> = {};

      if (includeGoat) {
        const goatRes = await fetchGoatMatchBySkuOrSlug({ sku: row.sku, slug: row.slug });
        if (debug) {
          goatStatusCounts[String(goatRes.status)] = (goatStatusCounts[String(goatRes.status)] ?? 0) + 1;
        }
        const goat = goatRes.product;
        if (goat?.id) {
          if (!sources.goat) goatAdded += 1;
          sources.goat = {
            link: goat.link ?? null,
            product_id: String(goat.id),
            sku: goat.sku ?? null,
            slug: goat.slug ?? null,
            updated_at: goat.updated_at ?? null
          };

          const dict: Record<string, number> = {};
          for (const v of goat.variants ?? []) {
            if (v?.available === false) continue;
            const sizeKey = String(v.size ?? "").toLowerCase().trim();
            const price = v.lowest_ask;
            if (!sizeKey || typeof price !== "number") continue;
            dict[sizeKey] = typeof dict[sizeKey] === "number" ? Math.min(dict[sizeKey], price) : price;
          }
          patchBySource.goat = dict;
        }
      }

      if (includeUnified) {
        const identifier = row.sku || row.slug;
        if (identifier) {
          const unifiedRes = await fetchUnifiedMatches(identifier, safeSimilarity);
          if (debug) {
            unifiedStatusCounts[String(unifiedRes.status)] = (unifiedStatusCounts[String(unifiedRes.status)] ?? 0) + 1;
          }
          for (const p of unifiedRes.matches) {
            const shopName = String(p.shop_name ?? "");
            if (!shopName) continue;
            const key = normalizeShopKey(shopName);
            if (!key) continue;

            // Skip overwriting stockx/goat if we already have them (they have better size pricing elsewhere).
            if ((key === "stockx" || key === "goat") && sources[key]) continue;

            if (!sources[key]) unifiedAdded += 1;
            sources[key] = {
              link: p.link ?? null,
              source_product_id: p.source_product_id ?? null,
              shop_name: p.shop_name ?? null,
              sku: p.sku ?? null,
              prices: p.prices ?? null,
              updated_at: p.updated_at ?? null
            };
          }
        }
      }

      // Ensure stockx exists in order even if sources doesn't have it (should, but be safe).
      if (!sources.stockx) {
        sources.stockx = { link: null };
      }

      const newOrder = recomputeSourcesOrder(sources);
      const merged = mergePricesBySize({
        oldOrder,
        oldPricesBySize: oldPrices as any,
        newOrder,
        patchBySource
      });

      updates.push({
        id: row.id,
        sources_order: newOrder,
        sources,
        prices_by_size: merged
      });
    }

    // Apply updates sequentially to avoid timeouts from massive payloads
    let applied = 0;
    for (const u of updates) {
      const { error: updErr } = await supabase
        .from("unified_sneakers")
        .update({
          sources_order: u.sources_order,
          sources: u.sources,
          prices_by_size: u.prices_by_size,
          updated_at: new Date()
        })
        .eq("id", u.id);
      if (updErr) throw new Error(updErr.message);
      applied += 1;
    }

    return new Response(JSON.stringify({
      offset,
      limit,
      applied,
      goatAdded,
      unifiedAdded,
      ...(debug ? { goatStatusCounts, unifiedStatusCounts } : {})
    }), { status: 200 });
  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

