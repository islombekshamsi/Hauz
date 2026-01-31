import { loadSync } from "https://deno.land/std@0.203.0/dotenv/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const localEnv = loadSync({ envPath: ".env" });
const getEnv = (key: string) => Deno.env.get(key) ?? localEnv[key];

const SUPABASE_URL = getEnv("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = getEnv("SUPABASE_SERVICE_ROLE_KEY");
const KICKSDB_API_KEY = getEnv("KICKSDB_API_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !KICKSDB_API_KEY) {
  throw new Error("Missing required environment variables");
}

const KICKS_ENDPOINT = "https://api.kicks.dev/v3/stockx/products";
const MAX_RECORDS = 500;
const PAGE_SIZE = 100;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function fetchKicksPage(limit: number, page: number) {
  const url = new URL(KICKS_ENDPOINT);
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("page", String(page));

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${KICKSDB_API_KEY}`,
    },
  });

  const rawBody = await response.text();
  if (!response.ok) {
    console.error("KicksDB request failed", response.status, rawBody);
    throw new Error(`KicksDB request failed (${response.status})`);
  }

  let body: any;
  try {
    body = JSON.parse(rawBody);
  } catch (err) {
    console.error("Unable to parse KicksDB response", rawBody);
    throw err;
  }

  if (!Array.isArray(body?.data)) {
    console.error("KicksDB response missing data array", body);
    throw new Error("KicksDB response missing data array");
  }

  console.log(`Fetched ${body.data.length} records from page ${page}`);
  return body.data;
}

async function run() {
  const aggregated: any[] = [];
  let page = 1;

  while (aggregated.length < MAX_RECORDS) {
    const limit = Math.min(PAGE_SIZE, MAX_RECORDS - aggregated.length);
    const data = await fetchKicksPage(limit, page);
    if (!data.length) break;
    aggregated.push(...data);
    if (data.length < limit) break;
    page += 1;
  }

  if (!aggregated.length) {
    throw new Error("No sneaker data returned from KicksDB");
  }

  const sneakers = aggregated.map((item: any) => ({
    id: item.id,
    name: item.name ?? item.title ?? item.primary_title ?? "Unknown sneaker",
    brand: item.brand ?? item.secondary_title ?? null,
    link: item.link ?? null,
    image_url: item.image ?? null,
    retail_price:
      item.retail_prices?.property1 ?? item.min_price ?? item.max_price ?? null,
    release_date: item.release_date
      ? new Date(item.release_date)
      : item.created_at
        ? new Date(item.created_at)
        : null,
    created_at: new Date(),
    last_updated: new Date(),
  }));

  const { error } = await supabase.from("sneakers").upsert(sneakers);
  if (error) throw error;

  console.log(`Inserted/updated ${sneakers.length} sneakers`);
}

run()
  .then(() => {
    console.log("Sync complete");
  })
  .catch((err) => {
    console.error(err);
    Deno.exit(1);
  });


