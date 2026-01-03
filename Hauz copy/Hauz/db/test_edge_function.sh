#!/bin/bash

# Test script to verify Edge Function works after adding OpenAI key secret

echo "🧪 Testing generate-search-embedding Edge Function..."
echo ""

SUPABASE_URL="https://bwrpauovmxablkbxschv.supabase.co"
ANON_KEY="sb_publishable_LGnigtrJ5KwtYE4Lq4BC-Q_HTVr1zkh"

# Test with a simple query
curl -X POST \
  "${SUPABASE_URL}/functions/v1/generate-search-embedding" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query": "basketball shoes"}' \
  --silent \
  | jq '.'

echo ""
echo "✅ If you see an embedding array above (1536 numbers), it works!"
echo "❌ If you see an error about OPENAI_API_KEY, add it to Supabase secrets"



