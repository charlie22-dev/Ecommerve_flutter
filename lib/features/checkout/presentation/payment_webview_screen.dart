import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/paymongo_config.dart';
import '../../../core/theme/app_color_tokens.dart';

/// Hosts a PayMongo e-wallet (GCash/Maya) or 3-D Secure checkout page and
/// pops with `true`/`false` once the configured success/failure redirect
/// URL is hit, instead of letting the user leave the app.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.checkoutUrl});

  final String checkoutUrl;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onNavigationRequest: _onNavigationRequest),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (_resolved) return NavigationDecision.navigate;

    if (request.url.startsWith(PaymongoConfig.successRedirectUrl)) {
      _resolved = true;
      Navigator.of(context).pop(true);
      return NavigationDecision.prevent;
    }
    if (request.url.startsWith(PaymongoConfig.failedRedirectUrl)) {
      _resolved = true;
      Navigator.of(context).pop(false);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete payment'),
        leading: IconButton(
          tooltip: 'Cancel payment',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      backgroundColor: context.colors.background,
      body: WebViewWidget(controller: _controller),
    );
  }
}
