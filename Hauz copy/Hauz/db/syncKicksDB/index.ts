import { loadSync } from "https://deno.land/std@0.203.0/dotenv/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Read keys from .env
let localEnv: Record<string, string> = {};
const rootEnvPath = new URL("../../../.env", import.meta.url).pathname;
try {
  console.log("Attempting to load local env file from", rootEnvPath);
  localEnv = loadSync({
    envPath: rootEnvPath
  });
} catch {
  console.warn("Local .env file not found; relying on injected environment variables.");
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

console.log("syncKicksDB env loaded", {
  hasSupabaseUrl: Boolean(SUPABASE_URL),
  hasServiceKey: Boolean(SUPABASE_SERVICE_ROLE_KEY),
  hasKicksKey: Boolean(KICKSDB_API_KEY),
  supabaseUrl: SUPABASE_URL,
  cwd: Deno.cwd(),
  pwdEnv: Deno.env.get("PWD")
});

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const KICKS_ENDPOINT = "https://api.kicks.dev/v3/stockx/products";
const STOCKX_PRICES_ENDPOINT = "https://api.kicks.dev/v3/stockx/prices";
const DEFAULT_PAGE_SIZE = 100;
const MAX_LIMIT_PER_REQUEST = 100;
const DEFAULT_PAGE_COUNT = 5;
// 18.9k shoes @ 100/page ≈ 190 pages. Keep this high so you can run large backfills in chunks.
const MAX_PAGE_COUNT = 250;

const footwearKeywords = ["sneaker", "shoe", "shoes", "trainer", "boot"];

const parseBool = (value: string | null, fallback: boolean) => {
  if (value === null) return fallback;
  const v = value.toLowerCase().trim();
  if (["1", "true", "yes", "y", "on"].includes(v)) return true;
  if (["0", "false", "no", "n", "off"].includes(v)) return false;
  return fallback;
};

type FetchOptions = {
  query?: string;
  sort?: "release_date" | "rank";
  filters?: string;
  market?: string;
  currency?: string;
};

type StockxPricesVariant = {
  id: string;
  size: string;
  size_type: string;
  price: number;
  type: "standard" | "express_standard" | "express_expedited";
};

type StockxPricesOutput = {
  product_id: string;
  sku: string;
  variants: StockxPricesVariant[] | null;
};

const fetchKicksPage = async (limit: number, page: number, options: FetchOptions) => {
  const url = new URL(KICKS_ENDPOINT);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("page", String(page));
  if (options.query) url.searchParams.set("query", options.query);
  if (options.sort) url.searchParams.set("sort", options.sort);
  if (options.filters) url.searchParams.set("filters", options.filters);
  if (options.market) url.searchParams.set("market", options.market);
  if (options.currency) url.searchParams.set("currency", options.currency);

  const response = await fetch(url, {
    headers: {
      "Authorization": `Bearer ${KICKSDB_API_KEY}`
    }
  });

  const rawBody = await response.text();
  if (!response.ok) {
    console.error("KicksDB request failed", response.status, rawBody);
    throw new Error(`KicksDB request failed (${response.status})`);
  }

  let body: any;
  try {
    body = JSON.parse(rawBody);
  } catch (parseError) {
    console.error("Unable to parse KicksDB response", rawBody);
    throw new Error("Unable to parse KicksDB response");
  }

  const data = Array.isArray(body?.data) ? body.data : null;
  if (!data) {
    console.error("KicksDB response missing data array", body);
    throw new Error("KicksDB response missing data array");
  }

  console.log(`Fetched ${data.length} records from page ${page}`);
  return data;
};

const normalizeSizeKey = (_sizeType?: string | null, size?: string | null) => {
  // Store plain size string keys to match app UX: { "10": [stockx, goat, ...] }.
  // If you ever need size_type disambiguation, we can store a second map in metadata.
  return (size ?? "").toLowerCase().trim();
};

const fetchStockxPricesBatch = async (productIds: string[], market?: string) => {
  if (!productIds.length) return [] as StockxPricesOutput[];

  const response = await fetch(STOCKX_PRICES_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${KICKSDB_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      market: market ?? "US",
      product_ids: productIds
    })
  });

  const rawBody = await response.text();
  if (!response.ok) {
    console.warn("StockX prices request failed; continuing without size prices", response.status, rawBody);
    return [] as StockxPricesOutput[];
  }

  let body: any;
  try {
    body = JSON.parse(rawBody);
  } catch {
    console.warn("Unable to parse StockX prices response; continuing without size prices");
    return [] as StockxPricesOutput[];
  }

  const data = Array.isArray(body?.data) ? body.data : [];
  return data as StockxPricesOutput[];
};

const parsePositiveInt = (value: string | null, fallback: number, max?: number) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  if (max) return Math.min(parsed, max);
  return parsed;
};

const isSneakerProduct = (item: any) => {
  const checkString = (value?: string | null) => {
    if (!value) return false;
    const lower = value.toLowerCase();
    return footwearKeywords.some((keyword) => lower.includes(keyword));
  };

  if (Array.isArray(item?.categories)) {
    const normalized = item.categories.map((cat: string) => cat?.toLowerCase?.());
    if (normalized.some((cat: string | undefined) => footwearKeywords.some((keyword) => cat?.includes(keyword)))) {
      return true;
    }
  }

  return (
    checkString(item?.category) ||
    checkString(item?.product_type) ||
    checkString(item?.secondary_category)
  );
};

// Serve the function
Deno.serve(async (req) => {
  try {
    // Require an extra shared secret to avoid exposing costly backfills to all authenticated users.
    if (SYNC_SECRET) {
      const provided = req.headers.get("x-sync-secret");
      if (!provided || provided !== SYNC_SECRET) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
      }
    } else {
      console.warn("SYNC_SECRET not set; relying only on Edge Function JWT verification.");
    }

    console.log("Function invoked");

    const url = new URL(req.url);
    const startPage = parsePositiveInt(url.searchParams.get("startPage"), 1);
    const pagesToFetch = parsePositiveInt(url.searchParams.get("pages"), DEFAULT_PAGE_COUNT, MAX_PAGE_COUNT);
    const limitPerPage = parsePositiveInt(url.searchParams.get("limit"), DEFAULT_PAGE_SIZE, MAX_LIMIT_PER_REQUEST);
    const includePrices = parseBool(url.searchParams.get("prices"), false);
    const maxRecords = pagesToFetch * limitPerPage;

    console.log(`Fetching sneakers starting at page ${startPage} for ${pagesToFetch} page(s) with page size ${limitPerPage}`);

    const kicksQuery = url.searchParams.get("query") ?? undefined;
    const sortParam = (url.searchParams.get("sort") as "release_date" | "rank" | null) ?? "rank";
    const filtersParam = url.searchParams.get("filters") ?? undefined;
    const marketParam = url.searchParams.get("market") ?? undefined;
    const currencyParam = url.searchParams.get("currency") ?? undefined;

    const aggregated: any[] = [];
    let page = startPage;
    let pagesFetched = 0;

    while (aggregated.length < maxRecords && pagesFetched < pagesToFetch) {
      const limit = Math.min(limitPerPage, maxRecords - aggregated.length);
      const pageData = await fetchKicksPage(limit, page, {
        query: kicksQuery ?? undefined,
        sort: sortParam,
        filters: filtersParam ?? undefined,
        market: marketParam ?? undefined,
        currency: currencyParam ?? undefined
      });
      if (!pageData.length) {
        break;
      }
      aggregated.push(...pageData);
      if (pageData.length < limit) {
        break;
      }
      page += 1;
      pagesFetched += 1;
    }

    if (!aggregated.length) {
      throw new Error("No sneaker data returned from KicksDB");
    }

    const filtered = aggregated.filter(isSneakerProduct);

    const pricesByProduct = new Map<string, Record<string, number[]>>();
    if (includePrices) {
      // Fetch size->price dictionaries from StockX in batches of 50 (API limit).
      const productIds: string[] = filtered.map((item: any) => String(item.id)).filter(Boolean);
      const priceBatchSize = 50;
      for (let i = 0; i < productIds.length; i += priceBatchSize) {
        const chunk = productIds.slice(i, i + priceBatchSize);
        const prices = await fetchStockxPricesBatch(chunk, marketParam);
        for (const p of prices) {
          const dict: Record<string, number[]> = {};
          for (const v of p.variants ?? []) {
            const key = normalizeSizeKey(v.size_type, v.size);
            if (!key) continue;
            const prev = dict[key]?.[0];
            const next = typeof prev === "number" ? Math.min(prev, v.price) : v.price;
            dict[key] = [next]; // aligned to sources_order: ['stockx']
          }
          pricesByProduct.set(String(p.product_id), dict);
        }
      }
    }

    const unifiedRows = filtered.map((item: any) => {
      const releaseDate = item.release_date
        ? new Date(item.release_date)
        : item.created_at
          ? new Date(item.created_at)
          : null;

      return {
        id: item.id,
        sku: item.sku ?? null,
        slug: item.slug ?? null,
        name: item.name ?? item.title ?? item.primary_title ?? "Unknown sneaker",
        brand: item.brand ?? null,
        model: item.model ?? item.primary_title ?? null,
        gender: item.gender ?? null,
        category: item.category ?? null,
        product_type: item.product_type ?? null,
        image_url: item.image ?? null,
        images: Array.isArray(item.gallery) ? item.gallery : [],
        retail_price: item.retail_prices?.property1 ?? item.min_price ?? item.max_price ?? null,
        release_date: releaseDate,
        sources_order: ["stockx"],
        sources: {
          stockx: {
            link: item.link ?? null,
            product_id: String(item.id),
            market: marketParam ?? null,
            currency: currencyParam ?? null
          }
        },
        prices_by_size: includePrices ? (pricesByProduct.get(String(item.id)) ?? {}) : {},
        metadata: {
          min_price: item.min_price ?? null,
          max_price: item.max_price ?? null,
          avg_price: item.avg_price ?? null,
          rank: item.rank ?? null,
          updated_at: item.updated_at ?? null
        },
        updated_at: new Date()
      };
    });

    const { error } = await supabase.from("unified_sneakers").upsert(unifiedRows);
    if (error) throw new Error(error.message);

    return new Response(JSON.stringify({
      inserted: unifiedRows.length,
      startPage,
      pages: pagesFetched,
      limit: limitPerPage,
      market: marketParam ?? null,
      currency: currencyParam ?? null
    }), { status: 200 });

  } catch (err: any) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});