const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const KICKSDB_API_KEY = process.env.KICKSDB_API_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !KICKSDB_API_KEY) {
  console.error("Missing required environment variables");
  process.exit(1);
}

const KICKS_ENDPOINT = "https://api.kicks.dev/v3/stockx/products";
const MAX_RECORDS = 500;
const PAGE_SIZE = 100;

async function fetchKicksPage(limit, page) {
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

  const body = JSON.parse(rawBody);
  if (!Array.isArray(body?.data)) {
    console.error("KicksDB response missing data array", body);
    throw new Error("KicksDB response missing data array");
  }

  console.log(`Fetched ${body.data.length} records from page ${page}`);
  return body.data;
}

function normalizeSneaker(item) {
  const releaseDate = item.release_date || item.created_at || null;
  return {
    id: item.id,
    name: item.name ?? item.title ?? item.primary_title ?? "Unknown sneaker",
    brand: item.brand ?? item.secondary_title ?? null,
    link: item.link ?? null,
    image_url: item.image ?? null,
    retail_price:
      item.retail_prices?.property1 ?? item.min_price ?? item.max_price ?? null,
    release_date: releaseDate ? new Date(releaseDate).toISOString() : null,
    created_at: new Date().toISOString(),
    last_updated: new Date().toISOString(),
  };
}

async function upsertSneakers(records) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/sneakers`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify(records),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error("Supabase upsert failed", response.status, body);
    throw new Error(`Supabase upsert failed (${response.status})`);
  }
}

async function main() {
  const aggregated = [];
  let page = 1;

  while (aggregated.length < MAX_RECORDS) {
    const limit = Math.min(PAGE_SIZE, MAX_RECORDS - aggregated.length);
    const pageData = await fetchKicksPage(limit, page);
    if (!pageData.length) break;
    aggregated.push(...pageData);
    if (pageData.length < limit) break;
    page += 1;
  }

  if (!aggregated.length) {
    throw new Error("No sneaker data returned from KicksDB");
  }

  const payload = aggregated.map(normalizeSneaker);
  await upsertSneakers(payload);
  console.log(`Inserted/updated ${payload.length} sneakers in Supabase`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});


