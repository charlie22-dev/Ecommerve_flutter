import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { paymentSnapshot } from "../_shared/xendit-payment.ts";

const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "Content-Type": "application/json" },
});

serve(async (req) => {
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  const expected = Deno.env.get("XENDIT_WEBHOOK_TOKEN");
  if (!expected) return reply({ error: "Webhook is not configured." }, 503);
  if (req.headers.get("x-callback-token") !== expected) return reply({ error: "Unauthorized" }, 401);
  try {
    // An authenticated invoice callback handles all channels offered on the
    // hosted checkout, including GCash, GrabPay, Maya, cards and banks.
    const payload = await req.json();
    if (!["PAID", "SETTLED", "EXPIRED"].includes(payload.status)) return reply({ received: true });
    const invoice = paymentSnapshot(payload);
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) return reply({ error: "Webhook is not configured." }, 503);
    const db = createClient(url, key);
    const { data: order, error } = await db.rpc("apply_xendit_invoice", {
      p_invoice: invoice, p_source: "webhook",
    });
    if (error) throw error;
    // This records late payments too, without shipping previously released stock.
    if (order.payment_status === "requires_review") {
      console.error("Paid closed order needs reconciliation", order.id, invoice.id);
    }
    return reply({ received: true, payment_status: order.payment_status });
  } catch (error) {
    console.error("Payment webhook error", error);
    return reply({ error: "Payment confirmation could not be recorded. Retry callback." }, 500);
  }
});
