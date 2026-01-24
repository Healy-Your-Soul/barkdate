// Follow Deno Deploy edge function pattern for Supabase
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Get service account credentials from environment
const PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!
const CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL')!
const PRIVATE_KEY = Deno.env.get('FIREBASE_PRIVATE_KEY')!.replace(/\\n/g, '\n')

// Generate OAuth2 access token using service account
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  // Create JWT for OAuth2
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: CLIENT_EMAIL,
      sub: CLIENT_EMAIL,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600, // 1 hour
      scope: "https://www.googleapis.com/auth/firebase.messaging"
    },
    await importPrivateKey(PRIVATE_KEY)
  )

  // Exchange JWT for access token
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })

  const data = await response.json()
  return data.access_token
}

// Import private key for JWT signing
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { token, title, body, type, data, imageUrl } = await req.json()

    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Missing FCM token' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get OAuth2 access token
    const accessToken = await getAccessToken()

    // Send notification via FCM v1 API
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: {
              title: title,
              body: body,
              ...(imageUrl && { image: imageUrl }),
            },
            data: {
              type: type || 'general',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              ...data,
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channel_id: type || 'default',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          },
        }),
      }
    )

    const result = await fcmResponse.json()

    if (!fcmResponse.ok) {
      console.error('FCM Error:', result)
      return new Response(
        JSON.stringify({ error: result.error?.message || 'FCM send failed' }),
        { status: fcmResponse.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('FCM Success:', result)
    return new Response(
      JSON.stringify({ success: true, messageId: result.name }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
