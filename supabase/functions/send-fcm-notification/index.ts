import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Helper to create Google OAuth2 Access Token from Service Account JSON
async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  function b64Url(data: string | Uint8Array): string {
    const str = typeof data === "string" ? btoa(data) : btoa(String.fromCharCode(...data));
    return str.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  }

  const encodedHeader = b64Url(JSON.stringify(header));
  const encodedClaim = b64Url(JSON.stringify(claim));
  const unsignedToken = `${encodedHeader}.${encodedClaim}`;

  // Clean PEM key
  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const jwt = `${unsignedToken}.${b64Url(new Uint8Array(signature))}`;

  // Exchange JWT for Access Token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenRes.json();
  if (!tokenRes.ok) {
    throw new Error(`Google token error: ${tokenData.error_description || tokenData.error}`);
  }
  return tokenData.access_token;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  try {
    const payload = await req.json();
    console.log("FCM Trigger Payload received:", JSON.stringify(payload));

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

    if (!supabaseUrl || !supabaseServiceKey || !serviceAccountRaw) {
      console.error("Missing required secrets (SUPABASE_URL, SERVICE_ROLE, or FIREBASE_SERVICE_ACCOUNT)");
      return new Response(JSON.stringify({ error: "Server configuration error" }), { status: 500 });
    }

    const serviceAccount = JSON.parse(serviceAccountRaw);
    const projectId = serviceAccount.project_id;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const accessToken = await getGoogleAccessToken(serviceAccount);

    const { table, record, old_record, type: eventType } = payload;
    let targetUserIds: string[] = [];
    let title = "";
    let body = "";
    let dataPayload: Record<string, string> = {};

    // 1. New Chat Message
    if (table === "messages" && (eventType === "INSERT" || record)) {
      const msg = record;
      // Get conversation details
      const { data: conv } = await supabase
        .from("conversations")
        .select("id, buyer_id, store_id, stores(owner_id, name)")
        .eq("id", msg.conversation_id)
        .single();

      if (conv) {
        const storeOwnerId = (conv.stores as any)?.owner_id;
        const storeName = (conv.stores as any)?.name || "BookVerse";

        // Send ONLY to the receiver, never the sender
        if (msg.sender_id === conv.buyer_id) {
          // Buyer sent -> notify store owner
          if (storeOwnerId) {
            targetUserIds.push(storeOwnerId);
            title = `New message from customer`;
            body = msg.body;
          }
        } else {
          // Seller or system sent -> notify buyer
          targetUserIds.push(conv.buyer_id);
          title = storeName;
          body = msg.body;
        }

        dataPayload = {
          type: "chat",
          conversation_id: conv.id,
          store_id: conv.store_id,
        };
      }
    }
    // 2. Orders Update or Insert
    else if (table === "orders") {
      const order = record;
      const orderNum = order.id ? order.id.slice(0, 8).toUpperCase() : "";

      if (eventType === "INSERT") {
        // New order -> Notify sellers with items in this order
        const { data: sellerOrders } = await supabase
          .from("seller_orders")
          .select("store_id, stores(owner_id)")
          .eq("order_id", order.id);

        if (sellerOrders) {
          for (const so of sellerOrders) {
            const ownerId = (so.stores as any)?.owner_id;
            if (ownerId && !targetUserIds.includes(ownerId)) {
              targetUserIds.push(ownerId);
            }
          }
        }
        title = "New Order Received!";
        body = `Order #${orderNum} has been placed for your store.`;
        dataPayload = { type: "order", order_id: order.id };
      } else if (eventType === "UPDATE") {
        // Status change -> Notify buyer
        if (old_record && old_record.status !== order.status) {
          targetUserIds.push(order.user_id);
          title = "Order Status Update";
          body = `Order #${orderNum} is now ${order.status}.`;
          dataPayload = { type: "order", order_id: order.id };
        }
      }
    }
    // 3. Seller Application Approval / Rejection
    else if (table === "seller_applications" && eventType === "UPDATE") {
      const app = record;
      if (old_record && old_record.status !== app.status && app.status !== "pending") {
        targetUserIds.push(app.user_id);
        title = app.status === "approved" ? "Store Approved! 🎉" : "Seller Application Update";
        body = app.status === "approved"
          ? `Welcome to BookVerse, ${app.store_name}! You can now start listing books.`
          : `Your application was not approved: ${app.admin_note || "No reason given."}`;
        dataPayload = { type: "seller_application", status: app.status };
      }
    }

    if (targetUserIds.length === 0) {
      return new Response(JSON.stringify({ message: "No targets to notify" }), { status: 200 });
    }

    // Also persist into in-app notifications table
    for (const uid of targetUserIds) {
      await supabase.from("notifications").insert({
        user_id: uid,
        title: title,
        body: body,
        type: dataPayload.type || "general",
        data: dataPayload,
        is_read: false,
      });
    }

    // Fetch device tokens for target users
    const { data: tokens, error: tokenErr } = await supabase
      .from("device_tokens")
      .select("fcm_token")
      .in("user_id", targetUserIds);

    if (tokenErr || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No registered device tokens" }), { status: 200 });
    }

    // Send FCM HTTP v1 push to each registered token
    const results = [];
    for (const t of tokens) {
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
      const fcmBody = {
        message: {
          token: t.fcm_token,
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            ...dataPayload,
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "bookverse_alerts",
              sound: "default",
            },
          },
        },
      };

      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmBody),
      });

      const resJson = await res.json();
      results.push({ token: t.fcm_token, status: res.status, res: resJson });
    }

    return new Response(JSON.stringify({ success: true, sent: results.length, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("FCM Edge Function Error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
