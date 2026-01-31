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
const STOCKX_PRODUCTS_ENDPOINT = "https://api.kicks.dev/v3/stockx/products";

type StockxVariant = {
  size: string;
  size_type: string;
  lowest_ask: number;
};

type StockxProduct = {
  id: string;
  title?: string | null;
  name?: string | null;
  sku?: string | null;
  slug?: string | null;
  link?: string | null;
  image?: string | null;
  gallery?: string[] | null;
  brand?: string | null;
  model?: string | null;
  gender?: string | null;
  category?: string | null;
  product_type?: string | null;
  retail_prices?: Record<string, unknown> | null;
  release_date?: string | null;
  created_at?: string | null;
  updated_at?: string | null;
  variants: StockxVariant[] | null;
};

const parseIntParam = (value: string | null, fallback: number, max?: number) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return fallback;
  const i = Math.trunc(n);
  if (typeof max === "number") return Math.min(i, max);
  return i;
};

const parseBool = (value: string | null, fallback: boolean) => {
  if (value === null) return fallback;
  const v = value.toLowerCase().trim();
  if (["1", "true", "yes", "y", "on"].includes(v)) return true;
  if (["0", "false", "no", "n", "off"].includes(v)) return false;
  return fallback;
};

const normalizeSizeKey = (_sizeType?: string | null, size?: string | null) =>
  (size ?? "").toLowerCase().trim();

async function fetchStockxProduct(id: string) {
  const url = new URL(`${STOCKX_PRODUCTS_ENDPOINT}/${encodeURIComponent(id)}`);
  url.searchParams.set("display[variants]", "true");

  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${KICKSDB_API_KEY}`,
    }
  });

  const raw = await response.text();
  if (!response.ok) {
    return { status: response.status, product: null as any, raw };
  }
  const body = JSON.parse(raw);
  return { status: response.status, product: (body?.data as StockxProduct) ?? null, raw };
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
    const limit = parseIntParam(url.searchParams.get("limit"), 50, 50);
    const market = (url.searchParams.get("market") ?? "US").toUpperCase();
    const idsParam = url.searchParams.get("ids");
    const debug = parseBool(url.searchParams.get("debug"), false);

    let rows: { id: string }[] = [];
    if (idsParam) {
      const ids = idsParam.split(",").map((s) => s.trim()).filter(Boolean);
      rows = ids.map((id) => ({ id }));
    } else {
      const { data, error } = await supabase
        .from("stockx_sneakers")
        .select("id")
        .order("updated_at", { ascending: false })
        .range(offset, offset + limit - 1);
      if (error) throw new Error(error.message);
      rows = (data ?? []) as any;
    }

    let updated = 0;
    let fetched = 0;
    let lastStatus = 0;
    let lastRaw = "";

    // For each product, fetch variants and derive size->lowest_ask dict.
    // (This works on Free keys; /v3/stockx/prices is subscription-gated.)
    for (const r of rows) {
      const pid = String(r.id);
      const res = await fetchStockxProduct(pid);
      lastStatus = res.status;
      lastRaw = res.raw;
      fetched += 1;

      const product = res.product;
      if (!product || !Array.isArray(product.variants)) continue;

      const dict: Record<string, number> = {};
      for (const v of product.variants ?? []) {
        const key = normalizeSizeKey(v.size_type, v.size);
        if (!key || typeof v.lowest_ask !== "number") continue;
        dict[key] = typeof dict[key] === "number" ? Math.min(dict[key], v.lowest_ask) : v.lowest_ask;
      }

      if (!Object.keys(dict).length) continue;
      const { error } = await supabase
        .from("stockx_sneakers")
        .update({
          sku: product.sku ?? null,
          slug: product.slug ?? null,
          name: product.title ?? product.name ?? undefined,
          brand: product.brand ?? null,
          model: product.model ?? null,
          gender: product.gender ?? null,
          category: product.category ?? null,
          product_type: product.product_type ?? null,
          link: product.link ?? null,
          image_url: product.image ?? null,
          images: Array.isArray(product.gallery) ? product.gallery : [],
          prices_by_size: dict,
          market,
          updated_at: new Date()
        })
        .eq("id", pid);
      if (error) throw new Error(error.message);
      updated += 1;
    }

    return new Response(JSON.stringify({
      requested: rows.length,
      fetched,
      updated,
      market,
      ...(debug ? { stockxProductStatus: lastStatus, stockxProductRaw: lastRaw.slice(0, 500) } : {})
    }), { status: 200 });
  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

