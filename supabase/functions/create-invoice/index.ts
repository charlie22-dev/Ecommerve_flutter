import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const secret = Deno.env.get("XENDIT_SECRET_KEY");
    if (!url || !key || !secret) return reply({ error: "Payment service is not configured." }, 503);
    const supabase = createClient(url, key);
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
    if (!token) return reply({ error: "Sign in to pay." }, 401);
    const { data: auth, error: authError } = await supabase.auth.getUser(token);
    if (authError || !auth.user) return reply({ error: "Sign in to pay." }, 401);

    const body = await req.json();
    const orderId = body.orderId ?? body.order_id;
    if (typeof orderId !== "string") return reply({ error: "Missing order ID." }, 400);
    const { data: order, error } = await supabase.from("orders")
      .select("id,user_id,total,status,payment_method,created_at,xendit_invoice_id,xendit_invoice_url")
      .eq("id", orderId).eq("user_id", auth.user.id).maybeSingle();
    if (error) throw error;
    if (!order) return reply({ error: "Order not found." }, 404);
    if (order.status !== "pending" || order.payment_method === "cashOnDelivery") {
      return reply({ error: "This order is not awaiting online payment." }, 409);
    }
    // Prices, shipping, tax and discounts are calculated by place_order.
    // Never trust an amount submitted by a client.
    const amount = Number(order.total);
    if (!Number.isFinite(amount) || amount <= 0) return reply({ error: "Invalid order total." }, 409);
    const remaining = Math.floor((new Date(order.created_at).getTime() + 30 * 60_000 - Date.now()) / 1000);
    if (remaining < 1) return reply({ error: "This order has expired. Please place a new order." }, 409);
    if (order.xendit_invoice_id && order.xendit_invoice_url) {
      return reply({ id: order.xendit_invoice_id, invoice_url: order.xendit_invoice_url });
    }
    const response = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: { Authorization: `Basic ${btoa(secret + ":")}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        external_id: order.id,
        amount,
        description: `Order #${order.id.substring(0, 8).toUpperCase()}`,
        currency: "PHP",
        invoice_duration: remaining,
        success_redirect_url: (() => {
          // Web checkout returns to this buyer's running application. Mobile
          // webviews intercept the configured success URL and verify payment.
          try {
            const target = new URL(body.returnUrl);
            const origin = req.headers.get("origin");
            if (target.origin === origin && target.hash === `#/order-confirmation/${order.id}` &&
                (target.protocol === "https:" || target.hostname === "localhost" || target.hostname === "127.0.0.1")) {
              return target.toString();
            }
          } catch (_) { /* Use the configured mobile redirect. */ }
          return "https://bookverse.app/payment/success";
        })(),
        failure_redirect_url: "https://bookverse.app/payment/failed",
        ...(auth.user.email ? { customer: { email: auth.user.email } } : {}),
      }),
    });
    const data = await response.json();
    if (!response.ok) {
      console.error("Invoice creation failed", response.status);
      return reply({ error: "Could not create the payment invoice. Please retry." }, 502);
    }
    if (typeof data.id !== "string" || typeof data.invoice_url !== "string") {
      throw new Error("Invalid invoice response");
    }
    const { error: saveError } = await supabase.from("orders").update({
      xendit_invoice_id: data.id, xendit_invoice_url: data.invoice_url,
    }).eq("id", order.id).eq("user_id", auth.user.id);
    if (saveError) throw saveError;
    return reply({ id: data.id, invoice_url: data.invoice_url, external_id: order.id });
  } catch (error) {
    console.error("Payment invoice error", error);
    return reply({ error: "Could not start payment. Please try again." }, 500);
  }
});
