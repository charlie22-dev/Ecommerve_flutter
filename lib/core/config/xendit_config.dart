/// Xendit payment gateway configuration for BookVerse.
///
/// Secret keys and webhook verification tokens are stored exclusively in
/// Supabase Secrets (XENDIT_SECRET_KEY and XENDIT_WEBHOOK_TOKEN) and accessed
/// only by Supabase Edge Functions (`create-invoice` and `xendit-webhook`).
abstract final class XenditConfig {
  /// Deep-link / return URLs after an online payment checkout completes.
  static const successRedirectUrl = 'https://bookverse.app/payment/success';
  static const failedRedirectUrl = 'https://bookverse.app/payment/failed';
}
