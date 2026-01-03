#!/bin/bash

# Embedding Generation Script for Hauz Sneakers
# Generates OpenAI embeddings for all 18,867 sneakers

FUNCTION_URL="https://bwrpauovmxablkbxschv.supabase.co/functions/v1/generate-embeddings"
ANON_KEY="sb_publishable_LGnigtrJ5KwtYE4Lq4BC-Q_HTVr1zkh"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        HAUZ - Embedding Generation Process                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "🚀 Starting embedding generation for 18,867 sneakers"
echo "⏱️  Estimated time: 10-20 minutes"
echo "📦 Processing 50 sneakers per batch"
echo "💰 Total cost: ~$0.02"
echo ""

batch=0
total_processed=0
total_errors=0
start_time=$(date +%s)

while true; do
  batch=$((batch + 1))
  current_time=$(date '+%H:%M:%S')
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Batch $batch | Time: $current_time"
  
  # Call the Edge Function
  response=$(curl -s -X POST "$FUNCTION_URL" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json")
  
  # Parse JSON response
  processed=$(echo "$response" | grep -o '"processed":[0-9]*' | grep -o '[0-9]*')
  errors=$(echo "$response" | grep -o '"errors":[0-9]*' | grep -o '[0-9]*')
  remaining=$(echo "$response" | grep -o '"remaining":[0-9]*' | grep -o '[0-9]*')
  success=$(echo "$response" | grep -o '"success":true')
  
  # Handle parsing failures
  if [ -z "$processed" ]; then
    processed=0
  fi
  if [ -z "$errors" ]; then
    errors=0
  fi
  
  # Update totals
  total_processed=$((total_processed + processed))
  total_errors=$((total_errors + errors))
  
  # Calculate progress
  if [ -n "$remaining" ] && [ "$remaining" != "0" ]; then
    completed=$((18867 - remaining))
    percentage=$((completed * 100 / 18867))
    
    echo "✅ Processed this batch: $processed"
    echo "❌ Errors this batch: $errors"
    echo "📊 Total processed: $total_processed / 18,867"
    echo "⏳ Remaining: $remaining"
    echo "📈 Progress: $percentage%"
    
    # Show progress bar
    bar_width=50
    filled=$((percentage * bar_width / 100))
    empty=$((bar_width - filled))
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%%\n" "$percentage"
    
    echo ""
  else
    # We're done!
    echo "✅ Processed this batch: $processed"
    echo "❌ Errors this batch: $errors"
    echo ""
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 ALL EMBEDDINGS GENERATED!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Total processed: $total_processed sneakers"
    echo "❌ Total errors: $total_errors"
    echo "⏱️  Total time: ${minutes}m ${seconds}s"
    echo "🚀 Your semantic search is now ready to use!"
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    NEXT STEPS                              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "1. 🏗️  Build and run your iOS app in Xcode"
    echo "2. 📱 Go to Feed tab → Tap the filter icon (slider)"
    echo "3. 🔍 Try searching:"
    echo "   • 'basketball shoes'"
    echo "   • 'something cool'"
    echo "   • 'winter shoes'"
    echo "   • 'running sneakers'"
    echo ""
    echo "✨ Enjoy your AI-powered search!"
    echo ""
    break
  fi
  
  # Check for errors
  if [ "$errors" -gt 40 ]; then
    echo "⚠️  Warning: High error rate detected. Continuing..."
  fi
  
  # Rate limit: 1 second between batches
  sleep 1
done






