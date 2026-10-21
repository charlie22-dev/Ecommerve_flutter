import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_providers.dart';
import '../../features/cart/presentation/cart_providers.dart';
import '../router/app_routes.dart';
import '../theme/app_color_tokens.dart';

/// Cart is a top-bar icon rather than its own bottom-nav tab — reused
/// wherever a screen's app bar needs quick access to checkout.
class CartIconButton extends ConsumerWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (isAdmin) return const SizedBox.shrink();

    final count = ref.watch(cartCountProvider);

    return Semantics(
      label: count > 0 ? 'Cart, $count item${count == 1 ? '' : 's'}' : 'Cart',
      button: true,
      child: IconButton(
        onPressed: () => context.push(AppRoute.cart),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_bag_outlined),
            if (count > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: context.colors.error, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
