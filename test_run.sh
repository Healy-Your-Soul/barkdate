#!/bin/bash
# Simple test runner that bypasses environment variable substitution

echo "🚀 Starting BarkDate with direct API key injection..."

# Kill any existing Flutter processes
pkill -f "flutter run" 2>/dev/null || true
sleep 2

# Clean and get dependencies
echo "🧹 Cleaning project..."
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null 2>&1

# Source environment variables
if [ -f .env ]; then
    source .env
    echo "✅ Environment variables loaded"
else
    echo "❌ .env file not found!"
    exit 1
fi

# Create a temporary HTML file with the API key injected
echo "🔧 Preparing web assets..."
cp web/index.html web/index.html.backup

# Inject the API key directly into the HTML
cat > web/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="BarkDate - Connect, Play, Grow Together">
  
  <!-- iOS meta tags & icons -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="BarkDate">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>BarkDate - Dog Playdates & Community</title>
  <link rel="manifest" href="manifest.json">
  
  <!-- Google Maps JavaScript API with optimized loading -->
  <script>
    function initGoogleMaps() {
      const script = document.createElement('script');
      script.src = 'https://maps.googleapis.com/maps/api/js?key=API_KEY_PLACEHOLDER&libraries=places&loading=async';
      script.async = true;
      script.defer = true;
      document.head.appendChild(script);
    }
    // Load Google Maps after page load
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', initGoogleMaps);
    } else {
      initGoogleMaps();
    }
  </script>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
EOF

# Replace the placeholder with the actual API key
sed -i '' "s/API_KEY_PLACEHOLDER/$GOOGLE_MAPS_API_KEY/g" web/index.html

echo "🎯 Starting Flutter app..."
flutter run -d chrome

# Restore original HTML file when done
echo "🧹 Restoring original HTML file..."
mv web/index.html.backup web/index.html
