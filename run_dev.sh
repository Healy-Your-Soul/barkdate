#!/bin/bash
# BarkDate Local Development Runner
# This script securely loads environment variables and starts the Flutter web app

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐕 BarkDate Local Development Setup${NC}"
echo "================================="

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo -e "${YELLOW}📝 Creating .env from template...${NC}"
    
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${GREEN}✅ .env file created from template${NC}"
        echo -e "${YELLOW}⚠️  Please edit .env and add your actual API keys before running again.${NC}"
        echo ""
        echo "Required API keys:"
        echo "1. GOOGLE_MAPS_API_KEY - Get from Google Cloud Console"
        echo "2. GOOGLE_PLACES_API_KEY - Get from Google Cloud Console"
        echo "3. FIREBASE_API_KEY - Get from Firebase Console"
        echo ""
        exit 1
    else
        echo -e "${RED}❌ .env.example template not found!${NC}"
        exit 1
    fi
fi

# Load environment variables
source .env

# Check if Google Maps API key is set
if [ -z "$GOOGLE_MAPS_API_KEY" ] || [ "$GOOGLE_MAPS_API_KEY" = "your_google_maps_api_key_here" ]; then
    echo -e "${RED}❌ GOOGLE_MAPS_API_KEY not set in .env file!${NC}"
    echo -e "${YELLOW}💡 Please edit .env and add your Google Maps API key${NC}"
    exit 1
fi

# Check if Google Places API key is set
if [ -z "$GOOGLE_PLACES_API_KEY" ] || [ "$GOOGLE_PLACES_API_KEY" = "your_google_places_api_key_here" ]; then
    echo -e "${YELLOW}⚠️  GOOGLE_PLACES_API_KEY not set - places search may not work${NC}"
fi

echo -e "${GREEN}✅ Environment variables loaded successfully${NC}"
echo -e "${BLUE}🚀 Starting BarkDate in development mode...${NC}"
echo ""

# Replace the placeholder in index.html with actual API key for development
sed "s/{{GOOGLE_MAPS_API_KEY}}/$GOOGLE_MAPS_API_KEY/g" web/index.html.template > web/index.html 2>/dev/null || true

# Start Flutter web app
flutter run -d chrome \
    --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY" \
    --dart-define=GOOGLE_PLACES_API_KEY="$GOOGLE_PLACES_API_KEY" \
    --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY"
