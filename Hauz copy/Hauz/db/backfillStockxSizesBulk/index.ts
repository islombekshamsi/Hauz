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

const parseIntParam = (value: string | null, fallback: number, max?: number) => {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  const i = Math.trunc(n);
  if (typeof max === "number") return Math.min(i, max);
  return i;
};

const normalizeSizeKey = (size?: string | null) => (size ?? "").toLowerCase().trim();

type StockxVariant = {
  size: string;
  lowest_ask: number;
  hidden?: boolean;
};

type StockxProduct = {
  id: string;
  title?: string | null;
  name?: string | null;
  brand?: string | null;
  model?: string | null;
  gender?: string | null;
  category?: string | null;
  product_type?: string | null;
  sku?: string | null;
  slug?: string | null;
  link?: string | null;
  image?: string | null;
  gallery?: string[] | null;
  retail_prices?: Record<string, unknown> | null;
  release_date?: string | null;
  created_at?: string | null;
  variants?: StockxVariant[] | null;
};

async function fetchStockxProductsPage(args: { page: number; limit: number; market?: string; currency?: string }) {
  const url = new URL(STOCKX_PRODUCTS_ENDPOINT);
  url.searchParams.set("page", String(args.page));
  url.searchParams.set("limit", String(args.limit));
  url.searchParams.set("display[variants]", "true");
  // The list endpoint also supports market/currency; variants include market + currency, but we store market separately.
  if (args.market) url.searchParams.set("market", args.market);
  if (args.currency) url.searchParams.set("currency", args.currency);

  const res = await fetch(url, {
    headers: { "Authorization": `Bearer ${KICKSDB_API_KEY}` }
  });
  const raw = await res.text();
  if (!res.ok) throw new Error(`KicksDB stockx/products failed (${res.status}): ${raw}`);
  const body = JSON.parse(raw);
  const data = Array.isArray(body?.data) ? body.data : [];
  return data as StockxProduct[];
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
    const startPage = parseIntParam(url.searchParams.get("startPage"), 1);
    const pages = parseIntParam(url.searchParams.get("pages"), 5, 50);
    const limit = parseIntParam(url.searchParams.get("limit"), 100, 100);
    const market = (url.searchParams.get("market") ?? "US").toUpperCase();
    const currency = url.searchParams.get("currency") ?? undefined;

    let fetchedProducts = 0;
    let updatedRows = 0;
    let pagesDone = 0;

    for (let p = startPage; p < startPage + pages; p++) {
      const products = await fetchStockxProductsPage({ page: p, limit, market, currency });
      pagesDone += 1;
      fetchedProducts += products.length;
      if (!products.length) break;

      const rows = products.map((prod) => {
        const dict: Record<string, number> = {};
        for (const v of prod.variants ?? []) {
          if (v?.hidden) continue;
          const key = normalizeSizeKey(v.size);
          const ask = v.lowest_ask;
          if (!key || typeof ask !== "number") continue;
          dict[key] = typeof dict[key] === "number" ? Math.min(dict[key], ask) : ask;
        }

        return {
          id: prod.id,
          sku: prod.sku ?? null,
          slug: prod.slug ?? null,
          name: (prod.title ?? prod.name) ?? "Unknown sneaker",
          brand: prod.brand ?? null,
          model: prod.model ?? null,
          gender: prod.gender ?? null,
          category: prod.category ?? null,
          product_type: prod.product_type ?? null,
          link: prod.link ?? null,
          image_url: prod.image ?? null,
          images: Array.isArray(prod.gallery) ? prod.gallery : [],
          retail_price: (prod as any)?.retail_prices?.property1 ?? null,
          release_date: prod.release_date ? new Date(prod.release_date) : null,
          prices_by_size: dict,
          market,
          currency: currency ?? null,
          updated_at: new Date()
        };
      });

      const { error } = await supabase.from("stockx_sneakers").upsert(rows);
      if (error) throw new Error(error.message);
      updatedRows += rows.length;

      if (products.length < limit) break;
    }

    return new Response(JSON.stringify({
      startPage,
      pagesRequested: pages,
      pagesDone,
      limit,
      market,
      fetchedProducts,
      updatedRows
    }), { status: 200 });
  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});

