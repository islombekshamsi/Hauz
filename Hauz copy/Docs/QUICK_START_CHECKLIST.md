# ✅ Quick Start Checklist - Semantic Search

## 🎯 Goal
Enable natural language search in your Hauz sneaker app so users can search with queries like "basketball shoes", "something cool for winter", etc.

---

## ✅ Already Done (By Me)

- [x] Enabled pgvector extension in Supabase
- [x] Added `search_metadata` and `embedding` columns to database
- [x] Generated searchable metadata for all 18,867 sneakers
- [x] Created `search_sneakers_semantic()` SQL function
- [x] Deployed `generate-embeddings` Edge Function
- [x] Created `SemanticSearchService.swift` in iOS app
- [x] Updated `FeedService.swift` with semantic search
- [x] Updated `FilterView` UI with search text field
- [x] Added example query chips for user guidance

---

## 📋 What YOU Need to Do (3 Steps)

### ☐ Step 1: Get OpenAI API Key (5 minutes)

1. Go to https://platform.openai.com/api-keys
2. Sign in or create account
3. Click "Create new secret key"
4. **Copy the key** (starts with `sk-proj-...`)
5. Add billing information (required for API usage)

**Cost:** ~$0.02 one-time + ~$0.00002 per search

---

### ☐ Step 2: Add API Key to iOS App (1 minute)

1. Open `Hauz/Secrets.swift` in Xcode
2. Find this line:
   ```swift
   let openAIKey = "YOUR_OPENAI_API_KEY_HERE"
   ```
3. Replace with your actual key:
   ```swift
   let openAIKey = "sk-proj-abc123..."
   ```
4. Save the file

⚠️ **Important:** Don't commit this file to Git!

---

### ☐ Step 3: Generate Embeddings (10-30 minutes, one-time)

This generates AI embeddings for all 18,867 sneakers. You only need to do this **once**.

#### Option A: Automated Script (Recommended)

1. **Add OpenAI key to Supabase:**
   - Go to https://supabase.com/dashboard/project/bwrpauovmxablkbxschv
   - Click: Settings → Edge Functions → Secrets
   - Add secret: `OPENAI_API_KEY` = `sk-proj-...` (your key)

2. **Create and run script:**
   
   Save this as `generate_embeddings.sh`:
   ```bash
   #!/bin/bash
   FUNCTION_URL="https://bwrpauovmxablkbxschv.supabase.co/functions/v1/generate-embeddings"
   ANON_KEY="sb_publishable_LGnigtrJ5KwtYE4Lq4BC-Q_HTVr1zkh"

   echo "🚀 Starting embedding generation..."
   echo "This will take 10-30 minutes for all 18,867 sneakers"
   echo ""

   for i in {1..400}; do
     echo "📦 Batch $i..."
     
     response=$(curl -s -X POST "$FUNCTION_URL" \
       -H "Authorization: Bearer $ANON_KEY" \
       -H "Content-Type: application/json")
     
     echo "$response"
     
     remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | grep -o '[0-9]*')
     
     if [ "$remaining" = "0" ]; then
       echo ""
       echo "✅ All embeddings generated!"
       echo "🎉 You're ready to test semantic search!"
       break
     fi
     
     sleep 1
   done
   ```

3. **Make executable and run:**
   ```bash
   chmod +x generate_embeddings.sh
   ./generate_embeddings.sh
   ```

4. **Wait for completion** (shows progress in terminal)

#### Option B: Manual (Click ~377 times)

1. Go to https://supabase.com/dashboard/project/bwrpauovmxablkbxschv
2. Click "Edge Functions" → `generate-embeddings`
3. Click "Invoke" button
4. Wait for response
5. Repeat until response shows `"remaining": 0`

---

### ☐ Step 4: Test! (5 minutes)

1. **Build and run** your app in Xcode
2. Navigate to **Feed** tab
3. Tap the **filter icon** (slider icon in bottom right)
4. You should see the new search field: "What are you looking for?"

**Try these queries:**
- "basketball shoes"
- "something cool"
- "winter shoes"
- "running sneakers"
- "affordable casual"
- "luxury designer"

**Expected behavior:**
1. Type query
2. Tap "Apply Filters"
3. Feed updates with relevant sneakers
4. Swipe through results!

---

## 🎉 Success Criteria

You'll know it's working when:

✅ Search field appears in FilterView  
✅ Example query chips are visible  
✅ Typing a query and tapping "Apply Filters" returns relevant sneakers  
✅ "basketball shoes" returns Air Jordans, LeBrons, etc.  
✅ "something cool" returns trendy sneakers  
✅ Results respect gender and price filters  

---

## 🐛 Troubleshooting

### Issue: "No results found"
**Cause:** Embeddings not generated yet  
**Fix:** Complete Step 3 above

### Issue: "OpenAI API error"
**Cause:** Invalid API key or no billing  
**Fix:** 
- Verify key in `Secrets.swift`
- Check OpenAI dashboard for billing status
- Make sure key starts with `sk-proj-`

### Issue: Search field not showing
**Cause:** Code not compiled  
**Fix:** Clean build folder (Cmd+Shift+K) and rebuild

### Check Embedding Status:
Run this in Supabase SQL Editor:
```sql
SELECT 
  COUNT(*) as total_sneakers,
  COUNT(embedding) as with_embeddings,
  COUNT(*) - COUNT(embedding) as remaining
FROM sneakers_only;
```

Should show:
- `total_sneakers`: 18867
- `with_embeddings`: 18867 (after Step 3 completes)
- `remaining`: 0

---

## 📚 Documentation

If you need more details:

- **Setup Guide:** `SEMANTIC_SEARCH_SETUP.md`
- **How It Works:** `SEMANTIC_SEARCH_COMPLETE_FLOW.md`
- **Architecture:** `ARCHITECTURE_DIAGRAM.md`
- **Summary:** `README_SEMANTIC_SEARCH.md`

---

## 💰 Cost Summary

### One-Time:
- Generate embeddings: **$0.02** (18,867 sneakers)

### Ongoing:
- Per search: **$0.00002**
- 1,000 searches: **$0.02**
- 10,000 searches/month: **$0.20/month**

**Very affordable!** Most apps spend < $1/month.

---

## ⏱️ Time Estimate

- **Step 1:** 5 minutes (get API key)
- **Step 2:** 1 minute (add to app)
- **Step 3:** 10-30 minutes (generate embeddings - automated)
- **Step 4:** 5 minutes (test)

**Total:** ~20-40 minutes

---

## 🚀 Next Steps After Testing

Once it works:

1. **Deploy to TestFlight** for beta testing
2. **Gather user feedback** on search quality
3. **Monitor costs** in OpenAI dashboard
4. **Adjust similarity threshold** if needed (see `SEMANTIC_SEARCH_SETUP.md`)
5. **Add more example queries** based on user behavior

---

## 📞 Need Help?

Check the documentation files or review:
- `SemanticSearchService.swift` - OpenAI integration
- `FeedService.swift` - Search orchestration
- `ContentView.swift` - UI implementation

All code is commented with explanations!

---

## ✨ That's It!

Complete Steps 1-4 and your users will have AI-powered search! 🎉

**Happy coding!** 🚀


