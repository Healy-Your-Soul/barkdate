#!/bin/bash

# 💡 INSTRUCTIONS: 
# 1. Replace the placeholder below with your actual Supabase service_role key
# 2. Add a secure password for your test accounts
# 3. Run: ./run_tests.sh

# Check if .env file exists
if [ -f .env ]; then
  set -a            # Automatically export all variables
  source .env       # Load the .env file
  set +a            # Stop automatically exporting
fi

if [ "$SUPABASE_SERVICE_ROLE_KEY" == "YOUR_SERVICE_ROLE_KEY_HERE" ]; then
  echo "❌ Error: Please provide your Supabase service_role key in run_tests.sh"
  exit 1
fi

if [ "$TEST_PASSWORD" == "YOUR_TEST_PASSWORD_HERE" ]; then
  echo "❌ Error: Please provide a TEST_PASSWORD in run_tests.sh"
  exit 1
fi

echo "=== 1. Seeding Verified Test Accounts ==="
# Using dart run to execute the Admin API seeder
dart run --define=SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY --define=TEST_PASSWORD=$TEST_PASSWORD scripts/seed_users.dart

echo "=== 2. Running Integration Tests ==="
flutter test integration_test --dart-define=TEST_PASSWORD=$TEST_PASSWORD
