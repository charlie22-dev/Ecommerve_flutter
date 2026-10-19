import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/xendit_config.dart';
import '../../../core/theme/app_color_tokens.dart';

/// Hosts a Xendit checkout page and automatically resolves with success
/// as soon as payment completes.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    this.orderId,
  });

  final String checkoutUrl;
  final String? orderId;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _launchInBrowser();
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) setState(() => _isLoading = true);
              _checkIfSuccessUrl(url);
            },
            onPageFinished: (url) {
              if (mounted) setState(() => _isLoading = false);
              _checkIfSuccessUrl(url);
            },
            onNavigationRequest: _onNavigationRequest,
          ),
        )
        ..loadRequest(Uri.parse(widget.checkoutUrl));
    }
  }

  void _checkIfSuccessUrl(String url) {
    if (_resolved) return;
    if (url.startsWith(XenditConfig.successRedirectUrl) ||
        url.contains('/payment/success') ||
        url.contains('status=PAID') ||
        url.contains('status=SUCCESS') ||
        url.contains('/invoices/success')) {
      _markOrderPaidAndPop();
    }
  }

  Future<void> _launchInBrowser() async {
    final uri = Uri.parse(widget.checkoutUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (_resolved) return NavigationDecision.navigate;

    if (request.url.startsWith(XenditConfig.successRedirectUrl) ||
        request.url.contains('/payment/success') ||
        request.url.contains('status=PAID') ||
        request.url.contains('status=SUCCESS') ||
        request.url.contains('/invoices/success')) {
      _markOrderPaidAndPop();
      return NavigationDecision.prevent;
    }
    if (request.url.startsWith(XenditConfig.failedRedirectUrl) ||
        request.url.contains('/payment/failed')) {
      _resolved = true;
      Navigator.of(context).pop(false);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _markOrderPaidAndPop() async {
    if (_resolved) return;
    _resolved = true;

    if (widget.orderId != null) {
      try {
        // Immediately mark order as toShip (paid) in Supabase
        await Supabase.instance.client
            .from('orders')
            .update({
              'status': 'toShip',
              'paid_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', widget.orderId!);

        await Supabase.instance.client
            .from('seller_orders')
            .update({'status': 'confirmed'})
            .eq('order_id', widget.orderId!);
      } catch (e) {
        debugPrint('Direct status update on success: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xendit Checkout'),
        leading: IconButton(
          tooltip: 'Cancel payment',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          TextButton.icon(
            onPressed: _markOrderPaidAndPop,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: colors.background,
      body: false
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_browser, size: 64, color: colors.accentBlue),
                    const SizedBox(height: 16),
                    const Text(
                      'Xendit Checkout opened in a new browser tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'After completing your payment on Xendit, tap "Done" in the top right to complete your order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _markOrderPaidAndPop,
                      icon: const Icon(Icons.check),
                      label: const Text('I Have Completed Payment'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                if (_controller != null) WebViewWidget(controller: _controller!),
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(color: colors.ink),
                  ),
              ],
            ),
    );
  }
}
