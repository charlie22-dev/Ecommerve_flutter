import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/xendit_config.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../data/order_repository.dart';

/// Hosts a Xendit checkout page and automatically resolves with success
/// as soon as payment completes.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.orderId,
    this.loadOrder,
    this.openCheckout = true,
  });

  final String checkoutUrl;
  final String orderId;
  final Future<Order?> Function(String)? loadOrder;
  final bool openCheckout;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _resolved = false;
  bool _checking = false;
  Timer? _poller;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPayment());

    _poller = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkPayment(),
    );
    if (!widget.openCheckout) {
      _isLoading = false;
    } else if (kIsWeb) {
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
    if (_isRedirect(url, XenditConfig.successRedirectUrl)) {
      _checkPayment();
    }
  }

  Future<void> _launchInBrowser() async {
    final uri = Uri.parse(widget.checkoutUrl);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Could not open checkout.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not open payment. Please try again.');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (_resolved) return NavigationDecision.navigate;

    if (_isRedirect(request.url, XenditConfig.successRedirectUrl)) {
      _checkPayment();
      return NavigationDecision.prevent;
    }
    if (_isRedirect(request.url, XenditConfig.failedRedirectUrl)) {
      _checkPayment();
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _checkPayment() async {
    if (_resolved || _checking || !mounted) return;
    setState(() => _checking = true);
    try {
      final load = widget.loadOrder ?? OrderRepository().refreshPayment;
      final order = await load(widget.orderId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || _resolved) return;
      final confirmed =
          order != null &&
          order.paymentMethod != PaymentMethod.cashOnDelivery &&
          order.isPaid &&
          {
            OrderStatus.toShip,
            OrderStatus.toReceive,
            OrderStatus.completed,
          }.contains(order.status);
      if (confirmed ||
          order?.status == OrderStatus.failed ||
          order?.status == OrderStatus.cancelled) {
        _resolved = true;
        _poller?.cancel();
        Navigator.of(context).pop(confirmed);
      } else {
        setState(
          () => _message = 'Awaiting payment confirmation. Your order will update automatically.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not check payment. Please check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  bool _isRedirect(String url, String target) {
    final uri = Uri.tryParse(url);
    final expected = Uri.parse(target);
    return uri?.scheme == expected.scheme &&
        uri?.host == expected.host &&
        uri?.port == expected.port &&
        uri?.path == expected.path;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resolved = true;
    _poller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPayment();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xendit Checkout'),
        leading: IconButton(
          tooltip: 'View order',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          TextButton.icon(
            onPressed: _checking ? null : _checkPayment,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text(
              'Check payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: colors.background,
      bottomNavigationBar: _message == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_message!, textAlign: TextAlign.center),
            ),
      body: kIsWeb || !widget.openCheckout
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.open_in_browser,
                      size: 64,
                      color: colors.accentBlue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Xendit Checkout opened in a new browser tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete payment in the payment window. Confirmation is checked automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _checking ? null : _checkPayment,
                      icon: const Icon(Icons.check),
                      label: const Text('Check payment status'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoading)
                  Center(child: CircularProgressIndicator(color: colors.ink)),
              ],
            ),
    );
  }
}
