Dispatch Playdate Reminders Edge Function

Purpose
- Runs on a schedule.
- Finds due rows in playdate_reminder_preferences.
- Creates notification rows.
- Sends FCM push via send-push-notification.
- Marks reminders as sent.

Required secrets
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- PLAYDATE_REMINDER_CRON_SECRET

Deploy
1) supabase functions deploy dispatch-playdate-reminders

Schedule in Supabase Dashboard
1) Open project dashboard.
2) Go to Edge Functions, select dispatch-playdate-reminders.
3) Create a schedule with cron expression: * * * * *
4) Method: POST
5) Add header: x-cron-secret = value of PLAYDATE_REMINDER_CRON_SECRET
6) Save.

Manual invoke test
- POST to /functions/v1/dispatch-playdate-reminders with header x-cron-secret.
- Expect JSON response with sentCount.
