import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fetchInvoice, XenditInvoiceError } from "../_shared/xendit-payment.ts";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });

function databaseFailure(error: { code?: string; message?: string }) {
  const code = error.code ?? "";
  const message = error.message ?? "";
  if (["42883", "PGRST202", "42703", "PGRST204"].includes(code) ||
      /apply_xendit_invoice|payment_status|xendit_invoice_id/i.test(message)) {
    return { code: "PAYMENT_MIGRATION_MISSING", message: "Verified payment database setup is missing." };
  }
  return { code: "PAYMENT_CHECK_FAILED", message: "Payment status could not be recorded." };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const secret = Deno.env.get("XENDIT_SECRET_KEY");
    if (!url || !key || !secret) return reply({ code: "PAYMENT_NOT_CONFIGURED", error: "Payment verification is not configured." }, 503);
    const db = createClient(url, key);
    const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
    if (!token) return reply({ error: "Sign in to check payment." }, 401);
    const { data: auth, error: authError } = await db.auth.getUser(token);
    if (authError || !auth.user) return reply({ error: "Sign in to check payment." }, 401);
    const { orderId } = await req.json();
    if (typeof orderId !== "string") return reply({ error: "Missing order ID." }, 400);
    const { data: order, error } = await db.from("orders").select().eq("id", orderId).maybeSingle();
    if (error) {
      console.error("Payment order lookup failed", error.code);
      return reply(databaseFailure(error), 502);
    }
    if (!order) return reply({ error: "Order not found." }, 404);
    if (order.user_id !== auth.user.id) {
      const { data: roles, error: rolesError } = await db.from("user_roles").select("role")
        .eq("user_id", auth.user.id).in("role", ["admin", "super_admin"]);
      if (rolesError) {
        console.error("Payment role lookup failed", rolesError.code);
        return reply(databaseFailure(rolesError), 502);
      }
      if (!roles?.length) return reply({ error: "Order not found." }, 404);
    }
    if (order.payment_method === "cashOnDelivery" || !order.xendit_invoice_id) {
      return reply({ order });
    }
    let invoice;
    try {
      invoice = await fetchInvoice(order.xendit_invoice_id, secret);
    } catch (error) {
      if (error instanceof XenditInvoiceError && [401, 403].includes(error.status)) {
        console.error("Xendit rejected the configured secret key", error.status);
        return reply({ code: "XENDIT_CREDENTIALS", error: "Xendit rejected the server key." }, 502);
      }
      if (error instanceof XenditInvoiceError && error.status === 404) {
        console.error("Xendit invoice was not found", order.id);
        return reply({ code: "XENDIT_INVOICE_NOT_FOUND", error: "Xendit invoice was not found." }, 502);
      }
      throw error;
    }
    if (invoice.external_id !== order.id) return reply({ code: "ORDER_INVOICE_MISMATCH", error: "Invoice does not match this order." }, 409);
    const { data: saved, error: saveError } = await db.rpc("apply_xendit_invoice", {
      p_invoice: invoice, p_source: "status_check",
    });
    if (saveError) {
      console.error("Verified Xendit payment could not be saved", saveError.code);
      return reply(databaseFailure(saveError), 502);
    }
    return reply({ order: saved });
  } catch (error) {
    console.error("Payment verification failed", error instanceof Error ? error.message : "unknown error");
    return reply({ code: "PAYMENT_CHECK_FAILED", error: "Payment status could not be verified. Check the Edge Function logs." }, 502);
  }
});
