# 🏗️ Semantic Search Architecture

## Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           HAUZ iOS APP                                   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                     ContentView.swift                           │    │
│  │                                                                  │    │
│  │  ┌────────────────────────────────────────────────────────┐   │    │
│  │  │              FilterView (UI)                            │   │    │
│  │  │                                                          │   │    │
│  │  │  ┌──────────────────────────────────────────────┐      │   │    │
│  │  │  │  Search TextField                             │      │   │    │
│  │  │  │  "What are you looking for?"                  │      │   │    │
│  │  │  │  [basketball shoes_____________]              │      │   │    │
│  │  │  └──────────────────────────────────────────────┘      │   │    │
│  │  │                                                          │   │    │
│  │  │  Example Chips:                                         │   │    │
│  │  │  [something cool] [winter shoes] [running sneakers]    │   │    │
│  │  │                                                          │   │    │
│  │  │  Price Range: $50 - $300                               │   │    │
│  │  │  Gender: [Male] [Female]                               │   │    │
│  │  │                                                          │   │    │
│  │  │  [Apply Filters] ←─────────────────────────────────┐   │   │    │
│  │  └──────────────────────────────────────────────────────┘   │   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
│                                   │ User taps "Apply Filters"            │
│                                   ▼                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    FeedService.swift                            │    │
│  │                                                                  │    │
│  │  func searchWithNaturalLanguage(                               │    │
│  │    query: "basketball shoes",                                  │    │
│  │    gender: "Male",                                             │    │
│  │    priceMin: 50,                                               │    │
│  │    priceMax: 300                                               │    │
│  │  )                                                              │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
│                                   │ Calls                                │
│                                   ▼                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              SemanticSearchService.swift                        │    │
│  │                                                                  │    │
│  │  func generateEmbedding(for: "basketball shoes")               │    │
│  │  func searchSneakers(query, gender, price...)                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
└───────────────────────────────────┼──────────────────────────────────────┘
                                    │
                                    │ HTTPS Request
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          OPENAI API                                      │
│                   https://api.openai.com/v1/embeddings                  │
│                                                                          │
│  Request:                                                                │
│  {                                                                       │
│    "model": "text-embedding-3-small",                                   │
│    "input": "basketball shoes"                                          │
│  }                                                                       │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │         AI Model (text-embedding-3-small)                   │        │
│  │                                                              │        │
│  │  "basketball shoes" → Mathematical Representation           │        │
│  │                                                              │        │
│  │  Converts text to 1536 numbers that capture meaning         │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                          │
│  Response:                                                               │
│  {                                                                       │
│    "data": [{                                                            │
│      "embedding": [0.0245, -0.1089, 0.4502, ..., 0.2298]               │
│    }]                                                                    │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Returns embedding
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           iOS APP                                        │
│                   SemanticSearchService.swift                           │
│                                                                          │
│  Now has query embedding: [0.0245, -0.1089, 0.4502, ..., 0.2298]      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Calls Supabase RPC
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE / POSTGRES                              │
│                   https://bwrpauovmxablkbxschv.supabase.co              │
│                                                                          │
│  RPC Call: search_sneakers_semantic(                                    │
│    query_embedding: [0.0245, -0.1089, 0.4502, ...],                    │
│    match_threshold: 0.7,                                                │
│    match_count: 40,                                                     │
│    gender_filter: "men",                                                │
│    price_min: 50,                                                       │
│    price_max: 300                                                       │
│  )                                                                       │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │              sneakers_only TABLE                            │        │
│  │                                                              │        │
│  │  ┌──────────┬─────────────────┬──────────────┬──────────┐ │        │
│  │  │ id       │ name            │ brand        │ embedding │ │        │
│  │  ├──────────┼─────────────────┼──────────────┼──────────┤ │        │
│  │  │ uuid-1   │ Air Jordan 1    │ Nike         │ [0.0251, │ │        │
│  │  │          │ Retro High OG   │              │ -0.1095, │ │        │
│  │  │          │                 │              │  0.4489, │ │        │
│  │  │          │                 │              │  ...]    │ │        │
│  │  ├──────────┼─────────────────┼──────────────┼──────────┤ │        │
│  │  │ uuid-2   │ Nike LeBron XX  │ Nike         │ [0.0243, │ │        │
│  │  │          │                 │              │ -0.1092, │ │        │
│  │  │          │                 │              │  0.4501, │ │        │
│  │  │          │                 │              │  ...]    │ │        │
│  │  ├──────────┼─────────────────┼──────────────┼──────────┤ │        │
│  │  │ uuid-3   │ Adidas Harden   │ Adidas       │ [0.0238, │ │        │
│  │  │          │ Vol. 7          │              │ -0.1088, │ │        │
│  │  │          │                 │              │  0.4495, │ │        │
│  │  │          │                 │              │  ...]    │ │        │
│  │  ├──────────┼─────────────────┼──────────────┼──────────┤ │        │
│  │  │   ...    │   ...           │   ...        │   ...    │ │        │
│  │  │ (18,867 total sneakers)                              │ │        │
│  │  └──────────┴─────────────────┴──────────────┴──────────┘ │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │              pgvector Extension                             │        │
│  │                                                              │        │
│  │  For each sneaker:                                          │        │
│  │    1. Calculate cosine similarity:                          │        │
│  │       similarity = 1 - (query <=> sneaker.embedding)        │        │
│  │                                                              │        │
│  │    Query:        [0.0245, -0.1089, 0.4502, ...]            │        │
│  │    Jordan 1:     [0.0251, -0.1095, 0.4489, ...] → 0.92 ✅  │        │
│  │    LeBron XX:    [0.0243, -0.1092, 0.4501, ...] → 0.89 ✅  │        │
│  │    Harden Vol.7: [0.0238, -0.1088, 0.4495, ...] → 0.87 ✅  │        │
│  │    Flip Flops:   [0.1234,  0.5678, -0.901, ...] → 0.12 ❌  │        │
│  │                                                              │        │
│  │    2. Filter:                                               │        │
│  │       - similarity > 0.7                                    │        │
│  │       - gender = "men"                                      │        │
│  │       - price >= 50 AND price <= 300                        │        │
│  │                                                              │        │
│  │    3. Sort by similarity (descending)                       │        │
│  │    4. Return top 40                                         │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                          │
│  Results:                                                                │
│  [                                                                       │
│    { id: uuid-1, name: "Air Jordan 1", similarity: 0.92 },             │
│    { id: uuid-2, name: "Nike LeBron XX", similarity: 0.89 },           │
│    { id: uuid-3, name: "Adidas Harden Vol. 7", similarity: 0.87 },    │
│    ... (37 more)                                                        │
│  ]                                                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Returns results
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           iOS APP                                        │
│                        FeedService.swift                                │
│                                                                          │
│  Receives 40 basketball sneakers                                        │
│  Filters out already-swiped sneakers                                    │
│  Updates feed: [SneakerCard]                                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Updates UI
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           HAUZ iOS APP                                   │
│                          MainView (Feed)                                │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │                    Swipeable Feed                           │        │
│  │                                                              │        │
│  │  ┌──────────────────────────────────────────────────┐      │        │
│  │  │                                                   │      │        │
│  │  │         Air Jordan 1 Retro High OG               │      │        │
│  │  │                                                   │      │        │
│  │  │              [Sneaker Image]                      │      │        │
│  │  │                                                   │      │        │
│  │  │         Nike • $170 • Men                        │      │        │
│  │  │                                                   │      │        │
│  │  │         Similarity: 92%                          │      │        │
│  │  │                                                   │      │        │
│  │  │         ← Swipe Left    Swipe Right →           │      │        │
│  │  │                                                   │      │        │
│  │  └──────────────────────────────────────────────────┘      │        │
│  │                                                              │        │
│  │  39 more basketball sneakers below...                       │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                          │
│  User can now swipe through relevant basketball shoes! 🏀               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Timeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│ TIME    │ COMPONENT              │ ACTION                               │
├─────────┼────────────────────────┼──────────────────────────────────────┤
│ 0ms     │ User                   │ Types "basketball shoes"             │
│ 10ms    │ FilterView             │ Captures input                       │
│ 20ms    │ User                   │ Taps "Apply Filters"                 │
│ 30ms    │ FeedService            │ Calls searchWithNaturalLanguage()    │
│ 40ms    │ SemanticSearchService  │ Calls generateEmbedding()            │
│ 50ms    │ iOS Network Layer      │ HTTPS POST to OpenAI API             │
│         │                        │                                      │
│ 250ms   │ OpenAI API             │ Processes "basketball shoes"         │
│         │                        │ Generates 1536-dimensional vector    │
│         │                        │                                      │
│ 500ms   │ iOS Network Layer      │ Receives embedding from OpenAI       │
│ 510ms   │ SemanticSearchService  │ Calls searchSneakers()               │
│ 520ms   │ iOS Network Layer      │ RPC call to Supabase                 │
│         │                        │                                      │
│ 530ms   │ Supabase/Postgres      │ Executes search_sneakers_semantic()  │
│ 540ms   │ pgvector               │ Compares query to 18,867 embeddings  │
│ 560ms   │ Postgres               │ Applies filters (gender, price)      │
│ 570ms   │ Postgres               │ Sorts by similarity                  │
│ 580ms   │ Postgres               │ Returns top 40 results               │
│         │                        │                                      │
│ 590ms   │ iOS Network Layer      │ Receives results from Supabase       │
│ 600ms   │ FeedService            │ Filters out swiped sneakers          │
│ 610ms   │ FeedService            │ Updates @Published feed property     │
│ 620ms   │ SwiftUI                │ UI automatically updates             │
│ 630ms   │ MainView               │ Displays 40 basketball sneakers      │
│         │                        │                                      │
│ TOTAL: ~630ms (less than 1 second!)                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Component Responsibilities

### iOS App Components

```
┌─────────────────────────────────────────────────────────────┐
│ ContentView.swift / FilterView                              │
├─────────────────────────────────────────────────────────────┤
│ • Displays search UI                                        │
│ • Captures user input                                       │
│ • Shows example queries                                     │
│ • Manages price/gender filters                             │
│ • Triggers search on "Apply Filters"                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ FeedService.swift                                           │
├─────────────────────────────────────────────────────────────┤
│ • Orchestrates search flow                                  │
│ • Manages feed state (@Published)                           │
│ • Filters out already-swiped sneakers                       │
│ • Handles errors and fallbacks                              │
│ • Tracks semantic search state                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SemanticSearchService.swift                                 │
├─────────────────────────────────────────────────────────────┤
│ • Calls OpenAI API for embeddings                           │
│ • Calls Supabase RPC for search                             │
│ • Handles API errors                                        │
│ • Converts results to SneakerCard objects                   │
└─────────────────────────────────────────────────────────────┘
```

### Backend Components

```
┌─────────────────────────────────────────────────────────────┐
│ OpenAI API (text-embedding-3-small)                         │
├─────────────────────────────────────────────────────────────┤
│ • Converts text to 1536-dimensional vectors                 │
│ • Captures semantic meaning                                 │
│ • Pre-trained on billions of text examples                  │
│ • Understands relationships (Jordan = basketball)           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Supabase / PostgreSQL                                       │
├─────────────────────────────────────────────────────────────┤
│ • Stores sneaker data + embeddings                          │
│ • Executes search_sneakers_semantic() function              │
│ • Applies filters (gender, price)                           │
│ • Returns results                                           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ pgvector Extension                                          │
├─────────────────────────────────────────────────────────────┤
│ • Stores vector embeddings efficiently                      │
│ • Calculates cosine similarity                              │
│ • Uses IVFFlat index for fast search                        │
│ • Handles 18,867 comparisons in ~10-50ms                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Edge Function: generate-embeddings                          │
├─────────────────────────────────────────────────────────────┤
│ • One-time setup function                                   │
│ • Fetches sneakers without embeddings                       │
│ • Sends to OpenAI API                                       │
│ • Stores embeddings back in database                        │
│ • Processes 50 sneakers per invocation                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Security & Privacy

```
┌─────────────────────────────────────────────────────────────┐
│ What OpenAI Sees:                                           │
├─────────────────────────────────────────────────────────────┤
│ ✅ Query text: "basketball shoes"                           │
│ ✅ Sneaker metadata: "Air Jordan 1 Nike men premium..."     │
│ ❌ User data (NO)                                           │
│ ❌ Purchase history (NO)                                    │
│ ❌ Personal information (NO)                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ What Stays in Your Database:                                │
├─────────────────────────────────────────────────────────────┤
│ ✅ All sneaker data                                         │
│ ✅ All embeddings                                           │
│ ✅ User swipe history                                       │
│ ✅ User preferences                                         │
│ ✅ Search happens entirely in YOUR database                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Performance Metrics

```
┌─────────────────────────────────────────────────────────────┐
│ Operation                    │ Time        │ Cost           │
├──────────────────────────────┼─────────────┼────────────────┤
│ Generate query embedding     │ 200-500ms   │ $0.00002       │
│ Search 18,867 sneakers       │ 10-50ms     │ Free           │
│ Total search time            │ 300-600ms   │ $0.00002       │
│                              │             │                │
│ Initial embedding generation │ 10-30 min   │ $0.02 (once)   │
│ (18,867 sneakers)            │             │                │
└─────────────────────────────────────────────────────────────┘
```

---

This architecture provides:
- ⚡ **Fast** searches (<1 second)
- 💰 **Affordable** (~$0.00002 per search)
- 🎯 **Accurate** (semantic understanding)
- 🔒 **Secure** (data stays in your database)
- 📈 **Scalable** (works with millions of sneakers)


