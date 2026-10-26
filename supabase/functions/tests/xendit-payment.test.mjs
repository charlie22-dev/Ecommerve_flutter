import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchInvoice, paymentSnapshot } from '../_shared/xendit-payment.ts';

const invoice = (channel = 'GCASH', status = 'PAID') => ({
  id: 'invoice-123', external_id: '12345678-0000-4000-8000-000000000001',
  status, currency: 'PHP', amount: 620, paid_amount: 620,
  paid_at: '2026-10-26T01:00:00.000Z', payment_id: 'payment-123',
  payment_method: 'EWALLET', payment_channel: channel,
});

for (const channel of ['GCASH', 'GRABPAY', 'PAYMAYA', 'CREDIT_CARD', 'BPI']) {
  test(`records the actual ${channel} channel and reference`, () => {
    const snapshot = paymentSnapshot(invoice(channel));
    assert.equal(snapshot.payment_channel, channel);
    assert.equal(snapshot.payment_id, 'payment-123');
    assert.equal(snapshot.paid_amount, 620);
    assert.equal(snapshot.paid_at, '2026-10-26T01:00:00.000Z');
  });
}

test('keeps pending distinct from paid and accepts settlement notifications', () => {
  assert.equal(paymentSnapshot(invoice('GCASH', 'PENDING')).status, 'PENDING');
  assert.equal(paymentSnapshot(invoice('GCASH', 'SETTLED')).status, 'SETTLED');
});

test('does not store customer, card or account details', () => {
  const snapshot = paymentSnapshot({ ...invoice(), customer: { email: 'private@example.com' },
    payment_details: { card_number: 'do-not-store' }, payment_destination: 'private-account' });
  assert.equal(snapshot.customer, undefined);
  assert.equal(snapshot.payment_details, undefined);
  assert.equal(snapshot.payment_destination, undefined);
});

test('supports optional paid amount and wallet channel fallback', () => {
  const data = invoice();
  delete data.payment_channel;
  delete data.paid_amount;
  const snapshot = paymentSnapshot({ ...data, ewallet_type: 'GRABPAY' });
  assert.equal(snapshot.payment_channel, 'GRABPAY');
  assert.equal(snapshot.paid_amount, undefined);
});

test('rejects invalid money, status and invoice identity', () => {
  for (const patch of [{ amount: 0 }, { amount: NaN }, { paid_amount: -1 },
    { paid_amount: Infinity }, { status: 'SUCCESS' }, { id: '' }]) {
    assert.throws(() => paymentSnapshot({ ...invoice(), ...patch }));
  }
});

test('server status check queries Xendit and preserves the provider truth', async () => {
  const request = async (url, options) => {
    assert.equal(url, 'https://api.xendit.co/v2/invoices/invoice-123');
    assert.equal(options.headers.Authorization, `Basic ${btoa('test-secret:')}`);
    return new Response(JSON.stringify(invoice('GRABPAY')), { status: 200 });
  };
  assert.equal((await fetchInvoice('invoice-123', 'test-secret', request)).payment_channel, 'GRABPAY');
});

test('failed provider lookup never becomes a successful payment', async () => {
  await assert.rejects(fetchInvoice('invoice-123', 'secret', async () => new Response('', { status: 500 })));
  await assert.rejects(fetchInvoice('different-invoice', 'secret', async () =>
    new Response(JSON.stringify(invoice()), { status: 200 })));
});
