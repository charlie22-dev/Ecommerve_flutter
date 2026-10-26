# Checkout and payment consistency update

Apply `migrations/20261026_checkout_payment_consistency.sql`, then the new `migrations/20261027_verified_online_payments.sql` in the Supabase SQL Editor. If the first migration was already applied, run only the new migration. Deploy all three functions before releasing this app version:

```sh
supabase functions deploy create-invoice --project-ref YOUR_PROJECT_REF
supabase functions deploy sync-payment --project-ref YOUR_PROJECT_REF
supabase functions deploy xendit-webhook --project-ref YOUR_PROJECT_REF --no-verify-jwt
```

SQL alone cannot deploy the TypeScript functions. The checked-in `config.toml` also configures the webhook JWT exception.

If the Supabase CLI is not installed, use `npx supabase` in place of `supabase` in those commands, and authenticate with `npx supabase login` first.

Configure `XENDIT_SECRET_KEY` and `XENDIT_WEBHOOK_TOKEN` as Supabase secrets. Configure the Xendit invoice callback to the deployed webhook URL. Deploy the webhook with JWT verification disabled (`supabase functions deploy xendit-webhook --no-verify-jwt`); it authenticates callbacks using `x-callback-token`. Keep JWT verification enabled for `create-invoice`.

Use `https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-webhook` for Xendit's invoice paid and expired notifications, in the same TEST or LIVE environment as the secret key. Set `XENDIT_WEBHOOK_TOKEN` to Xendit's verification token. Configure the invoice callback rather than an individual wallet callback: hosted invoice confirmation covers whichever enabled channel the shopper selects. Keep JWT verification enabled for `sync-payment`; it checks buyer ownership or administrator roles.

The webhook and `sync-payment` share the service-only `apply_xendit_invoice` SQL function. It locks the order, validates invoice identity, PHP currency and amount, and records the actual provider payment channel, transaction ID, amount paid, paid time and verification time. Summary fields live in `orders`; the durable provider record lives in `order_payments`, readable only by that buyer and admins. Stored details exclude customer account and card information. Payment status is separate from fulfillment status, so an order can display both Paid and To Ship.

The configured business tax is 12% of merchandise subtotal, rounded to two decimals, before voucher discount and excluding shipping. New orders store `tax_amount`; old orders retain their recorded amount and tax defaults to zero. COD, online invoices and receipts use the same database-calculated total. Confirm the business tax policy before production use.

Invoice creation requires an authenticated buyer who owns the pending order. The server uses the recorded total, and reuses the recorded invoice when payment is resumed. Invoice expiry uses the remaining portion of the order's existing 30-minute stock reservation. The hosted Xendit checkout does not send a `payment_methods` allow-list, so it can show all channels enabled on the merchant account (including GrabPay when available and activated). Check Xendit Dashboard → Payment Channels if a channel is missing; channel availability depends on the account and payment mode.

While the payment window is open the app asks the server to verify the invoice with Xendit every three seconds, and immediately after the app resumes. Pending order detail/confirmation screens retry every five seconds. The server's authenticated invoice GET API reconciles payment even if a webhook is delayed or missed. Web checkout supplies a validated return URL back to the app's order confirmation route. The admin screen checks up to four pending invoices when opened and every 20 seconds while visible; successful state changes update the order through Realtime. Check payment remains available for a manual retry and shows a specific setup or provider error when verification fails. Redirects alone cannot mark an order paid. Repeated callbacks cannot reset shipped/completed orders or repeat cart cleanup. A paid closed order is recorded with payment_status=requires_review, preserving the payment record without shipping released stock.

New checkout requests record whether the order came from the cart or Buy Now. Confirmation removes only purchased cart quantities in the same database transaction. This works after app exit, preserves unpurchased quantities and never removes cart items for Buy Now. The client refreshes cart state instead of deleting items a second time.

Live smoke checks after deployment:

1. Create a COD order and check that checkout, receipt and order list totals agree, including tax and voucher.
2. Open an online invoice and press Check payment before paying: it must remain pending. Closing payment opens the existing order record; Continue payment reopens that order's invoice.
3. Complete a sandbox payment and allow the webhook to arrive: show success once, then View Order opens the receipt. The receipt's top and device back buttons go Home.
4. Deliver a duplicate callback after shipping: neither the buyer order nor seller shipment should move backwards.
5. Reduce stock while another cart is open: stock and checkout eligibility should refresh. Attempting to buy the last copy twice must fail server-side for the second buyer.

Run SQL security tests only on a disposable database. The existing marketplace test file also contains legacy messaging assertions; use a schema-compatible test database when running it.

`tests/payment_consistency_test.sql` separately checks tax, totals, cart cleanup, Buy Now isolation and repeat confirmation. It requires the current schema/migrations and rolls back its fixtures.

`tests/verified_online_payments_test.sql` checks channel metadata for GCash, GrabPay, Maya, card and bank payments, invalid amounts, duplicate/out-of-order callbacks, late payments and service-only access. It rolls back its fixtures and returns `VERIFIED ONLINE PAYMENT TESTS PASSED` on success. This is a simulated database test, not a real Xendit charge.

Run payment helper tests locally with Node 24+: `node --test supabase/functions/tests/xendit-payment.test.mjs`.

Provider references: [Invoice GET endpoint](https://docs.xendit.co/docs/migrate-to-payment-session), [official invoice callback fields](https://github.com/xendit/xendit-node/blob/master/docs/invoice/InvoiceCallback.md), [invoice callback setup](https://docs.xendit.co/apidocs/set-webhook-url).
