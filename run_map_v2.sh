#!/bin/bash

# Quick Start Script for Map V2
# Run this after setting your API keys

echo "🚀 BarkDate Map V2 Quick Start"
echo "================================"
echo ""

# Check if API keys are set
if [ -z "$GEMINI_API_KEY" ]; then
    echo "⚠️  GEMINI_API_KEY not set!"
    echo "   Export it: export GEMINI_API_KEY=your_key_here"
    echo ""
fi

if [ -z "$GOOGLE_MAPS_API_KEY" ]; then
    echo "⚠️  GOOGLE_MAPS_API_KEY not set!"
    echo "   Export it: export GOOGLE_MAPS_API_KEY=your_key_here"
    echo ""
fi

# Install dependencies
echo "📦 Installing dependencies..."
flutter pub get

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed"
echo ""

# Check feature flag status
echo "🎯 Checking map_v2 feature flag..."
grep -n "_useMapV2 = true" lib/screens/main_navigation.dart > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Map V2 is ENABLED"
else
    echo "⚠️  Map V2 is DISABLED - set _useMapV2 = true in lib/screens/main_navigation.dart"
fi
echo ""

# Launch app
echo "🏃 Launching app..."
echo ""

flutter run \
  --dart-define=GEMINI_API_KEY="${GEMINI_API_KEY}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
