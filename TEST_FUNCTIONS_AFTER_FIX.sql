-- TEST DATABASE FUNCTIONS AFTER FIX
-- Run this AFTER running FIX_DATABASE_FUNCTIONS.sql

-- STEP 1: Get a real user ID to test with
SELECT 'Step 1: Getting real user ID...' as step;
SELECT id, email FROM auth.users LIMIT 1;

-- STEP 2: Test get_user_accessible_dogs function
-- Copy a real UUID from Step 1 and replace USER_ID_HERE
SELECT 'Step 2: Testing get_user_accessible_dogs function...' as step;
-- SELECT * FROM get_user_accessible_dogs('PASTE_REAL_UUID_HERE');

-- STEP 3: Check current dog_owners data
SELECT 'Step 3: Current dog_owners data...' as step;
SELECT do.*, d.name as dog_name, u.email as user_email
FROM dog_owners do
JOIN dogs d ON do.dog_id = d.id
LEFT JOIN auth.users u ON do.user_id = u.id
LIMIT 10;

-- STEP 4: Check if any dogs exist
SELECT 'Step 4: Current dogs data...' as step;
SELECT id, name, breed, age, user_id FROM dogs LIMIT 5;

-- STEP 5: Manual test instructions
SELECT 'Step 5: Manual Test Instructions' as step,
'1. Copy a user ID from Step 1
2. Replace PASTE_REAL_UUID_HERE in Step 2 with the real UUID
3. Run the updated Step 2 query
4. This should show dogs accessible to that user' as instructions;
