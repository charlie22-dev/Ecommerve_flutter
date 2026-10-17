/// PayMongo's **public** key only — safe to embed in the client because it
/// can only create/tokenize resources (e.g. card payment methods), never
/// move money or read secrets. The **secret** key lives exclusively in
/// `functions/` (Cloud Functions), never in this app.
///
/// Swap this for your own test key (`pk_test_...`) while developing, and a
/// live key (`pk_live_...`) only in your release build — see the "PayMongo
/// setup" section of README.md.
abstract final class PaymongoConfig {
  /// Publishable API key used by the mobile client for PayMongo tokenization requests.
  static const publicKey = 'pk_test_REPLACE_WITH_YOUR_PAYMONGO_PUBLIC_KEY';

  static const apiBase = 'https://api.paymongo.com/v1';

  /// Deep-link-style URLs PayMongo redirects back to after an e-wallet
  /// (GCash/Maya) checkout completes. The in-app WebView watches for these
  /// instead of letting the redirect leave the app.
  static const successRedirectUrl = 'https://bookverse.app/payment/success';
  static const failedRedirectUrl = 'https://bookverse.app/payment/failed';
}
