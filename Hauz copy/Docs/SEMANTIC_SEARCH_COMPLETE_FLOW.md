# 🎯 Complete Semantic Search Flow - Step by Step

This document explains EVERY SINGLE STEP of how semantic search works in your Hauz app, from start to finish.

---

## 📍 PHASE 1: ONE-TIME SETUP (Already Done!)

### Step 1: Database Preparation ✅

**What happened:**
```sql
-- 1. Enabled pgvector extension
create extension vector;

-- 2. Added columns to sneakers_only table
alter table sneakers_only 
add column search_metadata text;  -- Stores searchable text
add column embedding vector(1536); -- Stores AI embeddings

-- 3. Generated search metadata for all sneakers
update sneakers_only
set search_metadata = 'Air Jordan 1 Nike men premium basketball released 2023'
-- (for each of 18,867 sneakers)
```

**Result:** Your database is now ready to store AI embeddings!

---

### Step 2: Search Function Created ✅

**What happened:**
```sql
-- Created a function to search by vector similarity
create function search_sneakers_semantic(
  query_embedding vector(1536),  -- The search query as numbers
  match_threshold float,          -- How similar results must be
  match_count int,                -- How many results to return
  gender_filter text,             -- Optional gender filter
  price_min numeric,              -- Min price
  price_max numeric               -- Max price
)
```

**Result:** Supabase can now search sneakers by comparing vectors!

---

### Step 3: Edge Function Deployed ✅

**What happened:**
- Deployed `generate-embeddings` Edge Function to Supabase
- This function will process all 18,867 sneakers
- Sends their `search_metadata` to OpenAI
- Stores the embeddings back in the database

**Result:** You have a tool to generate embeddings for all sneakers!

---

## 📍 PHASE 2: GENERATE EMBEDDINGS (YOU NEED TO DO THIS)

### What You Need to Do:

1. **Get OpenAI API Key:**
   - Go to https://platform.openai.com/api-keys
   - Create new key
   - Copy it (starts with `sk-proj-...`)

2. **Add to Supabase:**
   - Supabase Dashboard → Settings → Edge Functions → Secrets
   - Add: `OPENAI_API_KEY` = `your-key-here`

3. **Run the Edge Function:**
   - Option A: Click "Invoke" in Supabase Dashboard (repeat ~377 times)
   - Option B: Use the bash script in SEMANTIC_SEARCH_SETUP.md

### What Happens When You Run It:

```
For each sneaker in database:
  1. Fetch: "Air Jordan 1 Nike men premium basketball released 2023"
  2. Send to OpenAI API
  3. Receive: [0.0234, -0.1123, 0.4521, ..., 0.2341] (1536 numbers)
  4. Store in database: sneakers_only.embedding column
```

**After this completes:** All 18,867 sneakers will have embeddings stored!

---

## 📍 PHASE 3: HOW SEARCH WORKS (When User Searches)

### Example: User Types "basketball shoes"

---

#### **Step 1: User Input**

```
User opens Filter menu
Types: "basketball shoes"
Taps: "Apply Filters"
```

---

#### **Step 2: iOS App Generates Query Embedding**

**File:** `SemanticSearchService.swift`

```swift
// 1. iOS sends query to OpenAI
let query = "basketball shoes"
let url = "https://api.openai.com/v1/embeddings"
let payload = {
  "model": "text-embedding-3-small",
  "input": "basketball shoes"
}

// 2. OpenAI returns embedding
let embedding = [0.0245, -0.1089, 0.4502, ..., 0.2298]
// (1536 numbers representing "basketball shoes")
```

**Time:** ~200-500ms

**What this means:** 
- OpenAI converts "basketball shoes" into a mathematical representation
- Similar concepts have similar numbers
- "basketball shoes" and "Air Jordan" will have similar vectors
- "basketball shoes" and "flip flops" will have different vectors

---

#### **Step 3: iOS Calls Supabase Search Function**

**File:** `SemanticSearchService.swift`

```swift
// Call Supabase RPC function
let results = try await supabase
  .rpc("search_sneakers_semantic", params: {
    "query_embedding": [0.0245, -0.1089, ...],  // From OpenAI
    "match_threshold": 0.7,                      // 70% similarity required
    "match_count": 40,                           // Return top 40
    "gender_filter": "men",                      // User's gender filter
    "price_min": 50,                             // User's price range
    "price_max": 300
  })
  .execute()
```

---

#### **Step 4: Supabase Compares Vectors**

**What happens in Postgres/pgvector:**

```sql
-- For EACH of the 18,867 sneakers:
-- 1. Calculate similarity between query and sneaker embedding

Query embedding:     [0.0245, -0.1089, 0.4502, ...]
Air Jordan 1:        [0.0251, -0.1095, 0.4489, ...]  → Similarity: 0.92 ✅
Nike Dunk Low:       [0.0198, -0.0876, 0.3821, ...]  → Similarity: 0.78 ✅
Yeezy Boost 350:     [0.0089, -0.0234, 0.2145, ...]  → Similarity: 0.65 ❌
Flip Flops:          [0.1234, 0.5678, -0.9012, ...]  → Similarity: 0.12 ❌

-- 2. Filter by:
--    - Similarity > 0.7 (threshold)
--    - Gender = "men"
--    - Price between $50-$300
--    - Price > $0 (exclude free/null prices)

-- 3. Sort by similarity (highest first)
-- 4. Return top 40 results
```

**Time:** ~10-50ms (pgvector is FAST!)

**Result:**
```json
[
  {
    "id": "uuid-1",
    "name": "Air Jordan 1 Retro High OG",
    "brand": "Nike",
    "similarity": 0.92
  },
  {
    "id": "uuid-2",
    "name": "Nike LeBron XX",
    "brand": "Nike",
    "similarity": 0.89
  },
  {
    "id": "uuid-3",
    "name": "Adidas Harden Vol. 7",
    "brand": "Adidas",
    "similarity": 0.87
  }
  // ... 37 more results
]
```

---

#### **Step 5: iOS Filters Out Already-Swiped Sneakers**

**File:** `FeedService.swift`

```swift
// Remove sneakers user already swiped on
let filtered = results.filter { 
  !swipedRightIDs.contains($0.id) &&  // Not liked
  !swipedLeftIDs.contains($0.id)      // Not disliked
}

// Update feed
feed = filtered
isSemanticSearchActive = true
currentSearchQuery = "basketball shoes"
```

---

#### **Step 6: User Sees Results**

**UI Updates:**
- Feed refreshes with 40 basketball sneakers
- User can swipe through them
- Each sneaker is relevant to "basketball shoes"
- Results respect gender and price filters

---

## 🧠 WHY THIS WORKS: The Magic of Embeddings

### Traditional Keyword Search (What We're NOT Doing):

```
User searches: "basketball shoes"

Database looks for exact matches:
- "Air Jordan 1" → ❌ No match (doesn't contain "basketball")
- "Nike Basketball Zoom" → ✅ Match (contains "basketball")
- "LeBron XX" → ❌ No match (doesn't contain "basketball")
```

**Problem:** Misses relevant results that don't contain exact keywords!

---

### Semantic Search with Embeddings (What We ARE Doing):

```
User searches: "basketball shoes"
OpenAI converts to: [0.0245, -0.1089, 0.4502, ...]

Database compares vectors:
- "Air Jordan 1" [0.0251, -0.1095, 0.4489, ...] → ✅ 92% similar!
  (AI knows Jordan = basketball)
  
- "Nike Basketball Zoom" [0.0248, -0.1087, 0.4495, ...] → ✅ 94% similar!
  (Contains "basketball" AND similar vector)
  
- "LeBron XX" [0.0243, -0.1092, 0.4501, ...] → ✅ 91% similar!
  (AI knows LeBron = basketball player)
  
- "Flip Flops" [0.1234, 0.5678, -0.9012, ...] → ❌ 12% similar
  (Completely different concept)
```

**Result:** Finds ALL relevant sneakers, even without exact keywords!

---

## 🎯 Real-World Examples

### Query: "something cool"

**What OpenAI understands:**
- "cool" = trendy, popular, stylish, fashionable
- Looks for sneakers with high similarity to these concepts

**Results:**
- Air Jordan 1 "Chicago" (iconic, trendy)
- Yeezy Boost 350 (popular, fashionable)
- Nike Dunk Low "Panda" (trending)

---

### Query: "winter shoes"

**What OpenAI understands:**
- "winter" = cold weather, boots, high-tops, warm, weather-resistant
- Looks for sneakers matching these characteristics

**Results:**
- Nike Air Force 1 High (high-top, ankle coverage)
- Timberland Field Boot (winter boot)
- Jordan 1 High (high-top design)

---

### Query: "running sneakers"

**What OpenAI understands:**
- "running" = athletic, performance, lightweight, cushioned
- Looks for running-specific shoes

**Results:**
- Nike Air Zoom Pegasus (running shoe)
- Adidas Ultraboost (performance running)
- New Balance 990 (running heritage)

---

## 💡 Key Takeaways

### 1. **OpenAI Never Sees Your Sneaker Data**
- You send sneaker descriptions to OpenAI ONCE
- Get embeddings back
- Store in YOUR database
- OpenAI doesn't store or access your data

### 2. **Search Happens in YOUR Database**
- All comparisons done by pgvector in Supabase
- Fast (10-50ms)
- Private (your data never leaves your server)

### 3. **Embeddings Capture Meaning**
- "basketball shoes" matches "Air Jordan" (even without keyword)
- "winter shoes" matches "boots" and "high-tops"
- "something cool" matches trendy, popular sneakers

### 4. **Works with Natural Language**
- Users can type conversationally
- "I want something cool for the gym"
- "Show me affordable running shoes"
- "Luxury sneakers for special occasions"

---

## 🎉 Summary

```
┌─────────────────────────────────────────────────────────┐
│ ONE-TIME SETUP (Already Done!)                          │
├─────────────────────────────────────────────────────────┤
│ 1. Enable pgvector in Supabase                    ✅   │
│ 2. Add embedding columns                           ✅   │
│ 3. Create search function                          ✅   │
│ 4. Deploy Edge Function                            ✅   │
│ 5. Update iOS app code                             ✅   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ YOU NEED TO DO (Once)                                   │
├─────────────────────────────────────────────────────────┤
│ 1. Get OpenAI API key                              ⏳   │
│ 2. Add to Secrets.swift                            ⏳   │
│ 3. Run generate-embeddings function                ⏳   │
│    (Takes 10-30 minutes for all 18,867 sneakers)        │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ EVERY SEARCH (Automatic)                                │
├─────────────────────────────────────────────────────────┤
│ 1. User types query                                     │
│ 2. iOS → OpenAI (generate query embedding)             │
│ 3. iOS → Supabase (search with embedding)              │
│ 4. Supabase compares to all sneaker embeddings          │
│ 5. Returns top 40 matches                               │
│ 6. iOS displays results                                 │
│                                                          │
│ Total time: ~300-600ms per search                       │
│ Cost: ~$0.00002 per search                              │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Next Steps

1. **Add your OpenAI API key** to `Secrets.swift`
2. **Run the embedding generation** (see SEMANTIC_SEARCH_SETUP.md)
3. **Test the feature** with example queries
4. **Deploy to TestFlight** and get user feedback!

You're ready to give your users an amazing search experience! 🎉


