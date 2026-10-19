import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Webhooks only receive POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Verify webhook authenticity using the x-callback-token header
    const expectedToken = Deno.env.get("XENDIT_WEBHOOK_TOKEN");
    const callbackToken = req.headers.get("x-callback-token");

    if (expectedToken && callbackToken !== expectedToken) {
      console.error("Webhook verification failed: Invalid x-callback-token");
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid callback token" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const payload = await req.json();
    console.log("Xendit Webhook Received:", JSON.stringify(payload));

    const { id, external_id, status, paid_at } = payload;

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("Missing Supabase Service Role credentials");
      return new Response(
        JSON.stringify({ error: "Supabase configuration error" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // When invoice status is PAID or SETTLED, mark order as confirmed / toShip
    if (status === "PAID" || status === "SETTLED") {
      const paidTimestamp = paid_at || new Date().toISOString();

      // Update public.orders (BookVerse schema)
      const { data: updatedOrders, error: orderErr } = await supabase
        .from("orders")
        .update({
          status: "toShip",
          paid_at: paidTimestamp,
          xendit_invoice_id: id,
        })
        .eq("id", external_id)
        .select();

      if (orderErr) {
        console.warn("Could not update orders by UUID:", orderErr.message);
        // Also attempt update by external_id or id if external_id is not UUID
        await supabase
          .from("orders")
          .update({
            status: "toShip",
            paid_at: paidTimestamp,
          })
          .eq("paymongo_reference_id", external_id);
      }

      // Update seller orders if present
      await supabase
        .from("seller_orders")
        .update({ status: "confirmed" })
        .eq("order_id", external_id);

      console.log(`Order ${external_id} successfully marked as PAID / toShip`);
    }

    return new Response(
      JSON.stringify({ received: true, status: status, external_id: external_id }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Error processing Xendit webhook:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Webhook processing error" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
