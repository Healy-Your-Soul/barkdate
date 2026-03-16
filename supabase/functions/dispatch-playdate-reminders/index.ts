// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("PLAYDATE_REMINDER_CRON_SECRET") ?? "";

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

function isReminderDue(
  now: Date,
  scheduledAtIso: string,
  minutesBefore: number,
  lastSentAtIso: string | null,
): boolean {
  if (lastSentAtIso) return false;
  const scheduledAt = new Date(scheduledAtIso);
  const triggerAt = new Date(scheduledAt.getTime() - minutesBefore * 60 * 1000);
  return now.getTime() >= triggerAt.getTime();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const providedSecret = req.headers.get("x-cron-secret") ?? "";
  if (CRON_SECRET && providedSecret != CRON_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const now = new Date();

    const { data: rows, error: queryError } = await supabase
      .from("playdate_reminder_preferences")
      .select(
        `
        id,
        user_id,
        playdate_id,
        playdate_request_id,
        minutes_before,
        last_sent_at,
        playdate:playdates!playdate_reminder_preferences_playdate_id_fkey(
          id,
          title,
          location,
          scheduled_at
        ),
        user:users!playdate_reminder_preferences_user_id_fkey(
          id,
          fcm_token
        )
      `,
      )
      .eq("enabled", true)
      .is("last_sent_at", null)
      .limit(200);

    if (queryError) {
      throw queryError;
    }

    let sentCount = 0;

    for (const raw of rows ?? []) {
      const row = raw as {
        id: string;
        user_id: string;
        playdate_id: string;
        playdate_request_id: string | null;
        minutes_before: number | null;
        last_sent_at: string | null;
        playdate: { title: string | null; location: string | null; scheduled_at: string | null } | null;
        user: { fcm_token: string | null } | null;
      };

      const scheduledAt = row.playdate?.scheduled_at;
      if (!scheduledAt) continue;

      const minutesBefore = row.minutes_before ?? 60;
      if (!isReminderDue(now, scheduledAt, minutesBefore, row.last_sent_at)) {
        continue;
      }

      const title = "Walk reminder";
      const body = `Your walk at ${row.playdate?.location ?? "the selected location"} starts soon.`;

      const { error: notificationError } = await supabase
        .from("notifications")
        .insert({
          user_id: row.user_id,
          title,
          body,
          type: "playdate",
          action_type: "playdate_reminder",
          related_id: row.playdate_id,
          metadata: {
            playdate_id: row.playdate_id,
            request_id: row.playdate_request_id,
            scheduled_at: scheduledAt,
            minutes_before: minutesBefore,
          },
          is_read: false,
          created_at: now.toISOString(),
        });

      if (notificationError) {
        console.error("Failed to insert reminder notification", notificationError);
        continue;
      }

      let badgeCount = 1;
      const { count: unreadCount } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("user_id", row.user_id)
        .eq("is_read", false);

      if ((unreadCount ?? 0) > 0) {
        badgeCount = unreadCount as number;
      }

      const fcmToken = row.user?.fcm_token;
      if (fcmToken) {
        try {
          await supabase.functions.invoke("send-push-notification", {
            body: {
              token: fcmToken,
              title,
              body,
              type: "playdate",
              data: {
                type: "playdate",
                action_type: "playdate_reminder",
                related_id: row.playdate_id,
                metadata: {
                  playdate_id: row.playdate_id,
                  request_id: row.playdate_request_id,
                  scheduled_at: scheduledAt,
                  minutes_before: minutesBefore,
                },
              },
              badgeCount,
            },
          });
        } catch (e) {
          console.error("Push send failed", e);
        }
      }

      const { error: updateError } = await supabase
        .from("playdate_reminder_preferences")
        .update({ last_sent_at: now.toISOString() })
        .eq("id", row.id)
        .is("last_sent_at", null);

      if (updateError) {
        console.error("Failed to mark reminder as sent", updateError);
        continue;
      }

      sentCount++;
    }

    return new Response(JSON.stringify({ success: true, sentCount }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("dispatch-playdate-reminders error", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
