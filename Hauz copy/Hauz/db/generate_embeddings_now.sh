#!/bin/bash

# Script to generate embeddings for all sneakers
# This will invoke the Edge Function repeatedly until all embeddings are generated

FUNCTION_URL="https://bwrpauovmxablkbxschv.supabase.co/functions/v1/generate-embeddings"
ANON_KEY="sb_publishable_LGnigtrJ5KwtYE4Lq4BC-Q_HTVr1zkh"

echo "🚀 Starting embedding generation for 18,867 sneakers..."
echo "⏱️  This will take approximately 10-20 minutes"
echo "📊 Processing 50 sneakers per batch"
echo ""

batch=0
total_processed=0
total_errors=0

while true; do
  batch=$((batch + 1))
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Batch $batch - $(date '+%H:%M:%S')"
  
  response=$(curl -s -X POST "$FUNCTION_URL" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json")
  
  # Parse response
  processed=$(echo "$response" | grep -o '"processed":[0-9]*' | grep -o '[0-9]*')
  errors=$(echo "$response" | grep -o '"errors":[0-9]*' | grep -o '[0-9]*')
  remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | grep -o '[0-9]*')
  
  # Update totals
  if [ -n "$processed" ]; then
    total_processed=$((total_processed + processed))
  fi
  if [ -n "$errors" ]; then
    total_errors=$((total_errors + errors))
  fi
  
  echo "✅ Processed: $processed sneakers"
  echo "❌ Errors: $errors"
  echo "⏳ Remaining: $remaining"
  echo "📊 Total processed so far: $total_processed"
  
  # Check if we're done
  if [ "$remaining" = "0" ] || [ -z "$remaining" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 ALL EMBEDDINGS GENERATED!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Total processed: $total_processed sneakers"
    echo "❌ Total errors: $total_errors"
    echo "🚀 Your semantic search is now ready to use!"
    echo ""
    echo "Next steps:"
    echo "1. Build and run your iOS app in Xcode"
    echo "2. Go to Feed tab → Tap filter icon"
    echo "3. Try searching: 'basketball shoes', 'something cool', etc."
    echo ""
    break
  fi
  
  # Show progress percentage
  completed=$((18867 - remaining))
  percentage=$((completed * 100 / 18867))
  echo "📈 Progress: $percentage% ($completed / 18867)"
  echo ""
  
  # Rate limit: wait 1 second between batches
  sleep 1
done

echo "✨ Done! Check your app now!"






