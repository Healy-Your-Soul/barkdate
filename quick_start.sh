#!/bin/bash
# Quick start script - loads .env and runs Flutter

if [ ! -f .env ]; then
    echo "❌ .env file not found! Please create it from .env.example"
    exit 1
fi

source .env

flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
