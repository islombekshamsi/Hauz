# 🔍 Semantic Search Setup Guide

## Overview
This guide walks you through setting up natural language search for your Hauz sneaker app using OpenAI embeddings and pgvector.

---

## ✅ What's Already Done

### Backend (Supabase)
- ✅ pgvector extension enabled
- ✅ `search_metadata` column added to `sneakers_only` table
- ✅ `embedding` column added (vector 1536 dimensions)
- ✅ Search metadata generated for all 18,867 sneakers
- ✅ `search_sneakers_semantic()` function created
- ✅ Edge Function `generate-embeddings` deployed

### Frontend (iOS)
- ✅ `SemanticSearchService.swift` created
- ✅ `FeedService` updated with semantic search support
- ✅ `FilterView` updated with search text field
- ✅ Example queries added for user guidance

---

## 🔑 Step 1: Get Your OpenAI API Key

1. Go to https://platform.openai.com/api-keys
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the key (starts with `sk-...`)
5. Add billing information (required for API usage)
   - Cost: ~$0.02 for initial embedding generation
   - Per search: ~$0.00002 (negligible)

---

## 🔧 Step 2: Add OpenAI API Key to Your App

Open `Hauz/Secrets.swift` and replace the placeholder:

```swift
// Replace this line:
let openAIKey = "YOUR_OPENAI_API_KEY_HERE"

// With your actual key:
let openAIKey = "sk-proj-..."
```

⚠️ **Important:** Never commit this file to Git! Add it to `.gitignore` if not already there.

---

## 🚀 Step 3: Generate Embeddings for All Sneakers

You need to run this **ONCE** to generate embeddings for all 18,867 sneakers.

### Option A: Using Supabase Dashboard (Recommended)

1. Go to https://supabase.com/dashboard/project/bwrpauovmxablkbxschv
2. Click "Edge Functions" in the left sidebar
3. Find `generate-embeddings` function
4. Click "Invoke" button
5. Wait for response (processes 50 sneakers per invocation)
6. **Repeat ~377 times** until all sneakers have embeddings

### Option B: Using cURL (Automated)

First, add your OpenAI API key to Supabase:

1. Go to Supabase Dashboard → Settings → Edge Functions
2. Add secret: `OPENAI_API_KEY` = `sk-proj-...`

Then run this script to process all sneakers:

```bash
#!/bin/bash
# Run this script to generate all embeddings

FUNCTION_URL="https://bwrpauovmxablkbxschv.supabase.co/functions/v1/generate-embeddings"
ANON_KEY="sb_publishable_LGnigtrJ5KwtYE4Lq4BC-Q_HTVr1zkh"

echo "Starting embedding generation..."

for i in {1..400}; do
  echo "Batch $i..."
  
  response=$(curl -s -X POST "$FUNCTION_URL" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json")
  
  echo "$response"
  
  # Check if we're done
  remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | grep -o '[0-9]*')
  
  if [ "$remaining" = "0" ]; then
    echo "✅ All embeddings generated!"
    break
  fi
  
  # Rate limit: wait 1 second between batches
  sleep 1
done
```

Save as `generate_embeddings.sh`, make executable (`chmod +x generate_embeddings.sh`), and run (`./generate_embeddings.sh`).

**Estimated time:** 10-30 minutes for all 18,867 sneakers

---

## 🧪 Step 4: Test the Feature

1. **Build and run** your app in Xcode
2. Navigate to the **Feed** tab
3. Tap the **filter icon** (slider icon)
4. You should see the new search field: "What are you looking for?"

### Test Queries:

Try these example queries:

- **"basketball shoes"** → Should return Air Jordans, LeBrons, etc.
- **"something cool"** → Returns trendy, popular sneakers
- **"winter shoes"** → Returns boots, high-tops, weather-resistant styles
- **"running sneakers"** → Returns athletic/performance shoes
- **"casual everyday wear"** → Returns lifestyle sneakers
- **"affordable cheap"** → Returns budget-friendly options
- **"luxury expensive"** → Returns premium sneakers

### Expected Behavior:

1. Type a query in the search field
2. Tap "Apply Filters"
3. App sends query to OpenAI → gets embedding
4. Supabase searches for similar sneakers
5. Feed updates with matching results
6. Swipe through the results!

---

## 📊 How It Works (Technical Flow)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. USER TYPES: "basketball shoes"                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. iOS App → OpenAI API                                     │
│    Request: Generate embedding for "basketball shoes"       │
│    Response: [0.0245, -0.1089, 0.4502, ..., 0.2298]        │
│              (1536 numbers)                                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. iOS App → Supabase RPC Function                         │
│    Call: search_sneakers_semantic(query_embedding, ...)    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Supabase/Postgres (pgvector)                            │
│    - Compares query vector to 18,867 sneaker vectors       │
│    - Uses cosine similarity                                 │
│    - Applies filters (gender, price)                        │
│    - Returns top 40 matches                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Results:                                                 │
│    - Air Jordan 1 Retro High OG (similarity: 0.92)         │
│    - Nike LeBron XX (similarity: 0.89)                     │
│    - Adidas Harden Vol. 7 (similarity: 0.87)              │
│    ...                                                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. iOS App displays results in swipeable feed              │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Breakdown

### One-Time Setup:
- **18,867 sneakers** × ~50 tokens avg = ~943,350 tokens
- Cost: $0.02 per 1M tokens = **~$0.02 total**

### Per Search Query:
- ~20 tokens per query
- Cost: $0.02 per 1M tokens = **~$0.00002 per search**
- **1,000 searches = $0.02**

### Monthly Estimate:
- If users perform 10,000 searches/month
- Cost: **$0.20/month**

**Very affordable!** 🎉

---

## 🔍 Troubleshooting

### Issue: "No results found"

**Possible causes:**
1. Embeddings not generated yet → Run Step 3
2. Query too specific → Try broader terms
3. Filters too restrictive → Adjust price range or gender

**Solution:** Check Supabase logs:
```sql
-- Check how many sneakers have embeddings
SELECT 
  COUNT(*) as total,
  COUNT(embedding) as with_embeddings
FROM sneakers_only;
```

### Issue: "OpenAI API error"

**Possible causes:**
1. Invalid API key
2. No billing set up on OpenAI account
3. Rate limit exceeded

**Solution:** 
- Verify API key in `Secrets.swift`
- Check OpenAI dashboard for billing status
- Wait a moment and try again

### Issue: "Semantic search error"

**Check logs in Xcode console:**
- Look for `🔍` emoji logs
- Check for error messages
- Verify Supabase connection

---

## 🎨 Customization

### Adjust Similarity Threshold

In `search_sneakers_semantic()` function, change `match_threshold`:

```sql
-- More strict (fewer, more relevant results)
match_threshold: 0.8

-- More lenient (more results, less relevant)
match_threshold: 0.6
```

### Add More Example Queries

In `ContentView.swift`, update `exampleQueries`:

```swift
private let exampleQueries = [
    "something cool",
    "winter shoes",
    "running sneakers",
    "casual style",
    "retro vibes",
    "basketball shoes",
    // Add your own:
    "gym workout",
    "street style",
    "limited edition"
]
```

### Modify Search Metadata

To improve search quality, update the metadata generation in Supabase:

```sql
update sneakers_only
set search_metadata = concat_ws(' ', 
  name, 
  brand, 
  gender,
  -- Add custom descriptors here
  'your custom keywords'
)
where id = 'specific-sneaker-id';
```

---

## 📚 Additional Resources

- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Supabase Vector Guide](https://supabase.com/docs/guides/ai/vector-columns)

---

## 🎉 You're All Set!

Once you complete Steps 1-3, your users can search for sneakers using natural language like:
- "I want something cool for the gym"
- "Show me retro basketball shoes"
- "Affordable running sneakers"
- "Luxury designer sneakers"

The AI will understand the intent and return relevant results! 🚀


