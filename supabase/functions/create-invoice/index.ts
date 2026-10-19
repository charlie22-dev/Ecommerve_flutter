import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const xenditSecretKey = Deno.env.get("XENDIT_SECRET_KEY");
    if (!xenditSecretKey) {
      throw new Error("XENDIT_SECRET_KEY is not set in Supabase Secrets.");
    }

    const body = await req.json();
    const orderId = body.orderId || body.order_id || `order_${Date.now()}`;
    const amount = Number(body.amount);
    const description =
      body.description || body.product_name || `Order #${orderId}`;
    const customerEmail = body.customerEmail || body.payer_email;

    if (!amount || amount <= 0) {
      throw new Error("Invalid or missing 'amount'.");
    }

    // Basic Auth header with Xendit Secret Key
    const basicAuth = btoa(`${xenditSecretKey}:`);

    const invoicePayload: Record<string, unknown> = {
      external_id: orderId.toString(),
      amount: amount,
      description: description,
      currency: "PHP",
      invoice_duration: 86400,
      success_redirect_url: "https://bookverse.app/payment/success",
      failure_redirect_url: "https://bookverse.app/payment/failed",
    };

    if (customerEmail) {
      invoicePayload.customer = { email: customerEmail };
    }

    // Call Xendit API to generate the invoice
    const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${basicAuth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(invoicePayload),
    });

    const invoiceData = await xenditResponse.json();

    if (!xenditResponse.ok) {
      console.error("Xendit API Error:", invoiceData);
      return new Response(
        JSON.stringify({
          error: "Xendit API error",
          details: invoiceData,
        }),
        {
          status: xenditResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Update order row in Supabase if order exists
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (supabaseUrl && supabaseServiceKey && orderId) {
      try {
        const supabase = createClient(supabaseUrl, supabaseServiceKey);
        await supabase
          .from("orders")
          .update({
            xendit_invoice_id: invoiceData.id,
            xendit_invoice_url: invoiceData.invoice_url,
          })
          .eq("id", orderId);
      } catch (dbErr) {
        console.warn("Could not update orders record:", dbErr);
      }
    }

    return new Response(
      JSON.stringify({
        invoice_url: invoiceData.invoice_url,
        invoiceUrl: invoiceData.invoice_url,
        external_id: orderId,
        id: invoiceData.id,
        status: invoiceData.status,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: any) {
    console.error("Error creating invoice:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
