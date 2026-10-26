export type Invoice = Record<string, unknown>;

export class XenditInvoiceError extends Error {
  constructor(readonly status: number) {
    super(`Xendit invoice lookup failed (${status})`);
  }
}

/** Persist transaction metadata only; never retain card/account/customer data. */
export function paymentSnapshot(invoice: Invoice): Invoice {
  const required = ["id", "external_id", "status", "currency"];
  for (const field of required) {
    if (typeof invoice[field] !== "string" || !(invoice[field] as string).trim()) {
      throw new Error(`Invalid invoice ${field}`);
    }
  }
  if (!["PENDING", "PAID", "SETTLED", "EXPIRED"].includes(invoice.status as string)) {
    throw new Error("Unsupported invoice status");
  }
  if (typeof invoice.amount !== "number" || !Number.isFinite(invoice.amount) || invoice.amount <= 0) {
    throw new Error("Invalid invoice amount");
  }
  if (invoice.paid_amount != null &&
      (typeof invoice.paid_amount !== "number" || !Number.isFinite(invoice.paid_amount) || invoice.paid_amount < 0)) {
    throw new Error("Invalid paid amount");
  }
  const snapshot: Invoice = {};
  for (const field of ["id", "external_id", "status", "currency", "amount", "paid_amount",
    "paid_at", "payment_id", "payment_method", "payment_channel", "ewallet_type", "bank_code", "updated"]) {
    if (invoice[field] != null) snapshot[field] = invoice[field];
  }
  if (!snapshot.payment_channel) snapshot.payment_channel = invoice.ewallet_type ?? invoice.bank_code ?? null;
  return snapshot;
}

/** Always call the provider with a server secret; redirects cannot establish payment. */
export async function fetchInvoice(invoiceId: string, secret: string, request = fetch): Promise<Invoice> {
  const response = await request(`https://api.xendit.co/v2/invoices/${encodeURIComponent(invoiceId)}`, {
    headers: { Authorization: `Basic ${btoa(secret + ":")}` },
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok) throw new XenditInvoiceError(response.status);
  const invoice = paymentSnapshot(await response.json());
  if (invoice.id !== invoiceId) throw new Error("Invoice ID mismatch");
  return invoice;
}
