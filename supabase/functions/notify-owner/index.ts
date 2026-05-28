import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import admin from "npm:firebase-admin@12";

let serviceAccount: any = {};
try {
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (serviceAccountJson) {
    serviceAccount = JSON.parse(serviceAccountJson);
  }
} catch (e) {
  console.error("Error parsing FIREBASE_SERVICE_ACCOUNT secret:", e);
}

if (!admin.apps.length && serviceAccount.project_id) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { tag_id, lat, lng } = await req.json();

    if (!tag_id) {
      return new Response(
        JSON.stringify({ error: "tag_id is required" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 1. Rate Limiting: Check for a scan in the last 5 minutes
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { data: recentScans, error: recentError } = await supabaseClient
      .from('scans')
      .select('created_at')
      .eq('tag_id', tag_id)
      .gte('created_at', fiveMinutesAgo)
      .limit(1);

    if (recentScans && recentScans.length > 0) {
      return new Response(
        JSON.stringify({ error: "Notification already sent recently. Please wait before trying again." }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Get tag and pet details
    const { data: tagData, error: tagError } = await supabaseClient
      .from('tags')
      .select(`
        pet_id,
        is_active,
        pets (
          owner_id,
          name
        )
      `)
      .eq('id', tag_id)
      .single();

    if (tagError || !tagData) {
      return new Response(
        JSON.stringify({ error: "Tag not found or database error" }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!tagData.is_active) {
      return new Response(
        JSON.stringify({ error: "Tag is inactive" }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const ownerId = (tagData.pets as any).owner_id;
    const petName = (tagData.pets as any).name;

    // 3. Get user devices
    const { data: devices, error: deviceError } = await supabaseClient
      .from('user_devices')
      .select('fcm_token')
      .eq('owner_id', ownerId);

    if (!devices || devices.length === 0) {
      return new Response(
        JSON.stringify({ message: "No devices registered for owner" }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Record the scan & generate Maps Link
    let bodyText = `Someone just scanned ${petName}'s tag.`;
    
    let scanLocation = null;
    if (lat && lng) {
        bodyText += `\nLocation provided! Tap to open Google Maps.`;
        scanLocation = `POINT(${lng} ${lat})`;
    }

    await supabaseClient.from('scans').insert({
        tag_id: tag_id,
        scan_location: scanLocation,
        lat: lat,
        lng: lng
    });

    const dataPayload: any = {
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    };

    if (lat && lng) {
        dataPayload.maps_url = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
        dataPayload.lat = String(lat);
        dataPayload.lng = String(lng);
    }

    // 5. Send FCM notification
    const tokens = devices.map(d => d.fcm_token);
    const payload = {
      notification: {
        title: "Pet Scanned!",
        body: bodyText,
      },
      data: dataPayload,
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(payload);

    return new Response(
      JSON.stringify({ message: "Notifications sent", details: response }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});