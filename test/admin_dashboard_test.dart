// Renders the admin dashboard and tables with sample data at phone and
// desktop widths, in light and dark themes. Any layout overflow fails.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/core/models/book.dart';
import 'package:my_app/core/models/order.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/admin/data/admin_repository.dart';
import 'package:my_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:my_app/features/admin/presentation/admin_orders_screen.dart';
import 'package:my_app/features/admin/presentation/admin_products_screen.dart';
import 'package:my_app/features/admin/presentation/admin_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Building the theme starts Figtree loading, which fails offline under
  // `flutter test`; text then falls back to the default font. Swallow just
  // those font errors so the real theme (all its colors) can be used.
  late final ThemeData light;
  late final ThemeData dark;
  runZonedGuarded(() {
    light = AppTheme.light;
    dark = AppTheme.dark;
  }, (error, _) {
    if (!'$error'.contains('was not found in the application assets')) throw error;
  });

  final today = DateTime.now();
  final sample = AdminDashboard(
    days: 7,
    grossSales: 48200,
    orderCount: 132,
    commission: 3950.5,
    customerCount: 870,
    activeSellers: 12,
    sales: [
      for (var i = 0; i < 7; i++) (start: today.subtract(Duration(days: 6 - i)), amount: i == 2 ? 0.0 : 1000.0 * (i + 1)),
    ],
    categories: const [(type: 'manga', amount: 26000), (type: 'manhwa', amount: 10100), (type: 'lightNovel', amount: 4000)],
  );

  Future<void> pump(WidgetTester tester, Size size, ThemeData theme) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        adminDashboardProvider.overrideWith((ref) => Stream.value(sample)),
        adminTodoProvider.overrideWith(
          (ref) => (toShip: 3, lowStock: 1, sellerApplications: 2, listingsToReview: 5, unansweredMessages: 0),
        ),
      ],
      child: MaterialApp(theme: theme, home: const AdminDashboardScreen()),
    ));
    await tester.pump();
  }

  for (final (name, size) in [('phone', const Size(360, 800)), ('desktop', const Size(1100, 900))]) {
    for (final (themeName, theme) in [('light', light), ('dark', dark)]) {
      testWidgets('dashboard renders on $name ($themeName)', (tester) async {
        await pump(tester, size, theme);
        expect(find.text('₱48,200.00'), findsWidgets);
        expect(find.text('To do'), findsOneWidget);
        expect(find.text('Orders to ship'), findsOneWidget);
        expect(find.text('Unanswered messages'), findsNothing, reason: 'zero counts are hidden');
        // Below the fold on phones — scroll to it (the list builds lazily).
        await tester.scrollUntilVisible(find.text('Manga'), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text('Manga'), findsOneWidget);
      });
    }
  }

  final orders = [
    for (final (i, status) in [OrderStatus.toShip, OrderStatus.pending, OrderStatus.completed].indexed)
      AdminOrder(
        order: Order(
          id: 'a1b2c3d4-0000-4000-8000-00000000000$i',
          uid: 'u$i',
          items: const [
            OrderLineItem(bookId: 'b1', title: 'One Piece, Vol. 1 — a very long title that must not overflow', coverUrl: '', unitPrice: 320, quantity: 2),
          ],
          subtotal: 640,
          shippingCost: 60,
          voucherCode: null,
          voucherDiscount: 0,
          total: 700,
          shippingAddress: null,
          shippingOptionId: 'standard',
          status: status,
          createdAt: today,
        ),
        customer: CustomerInfo(uid: 'u$i', name: 'Customer $i', email: 'customer$i@example.com'),
      ),
  ];
  final books = [
    const Book(id: 'b1', title: 'Naruto, Vol. 1', author: 'Masashi Kishimoto', price: 320, stock: 0),
    const Book(id: 'b2', title: 'Solo Leveling', author: 'Chugong', price: 450, stock: 3, listingStatus: 'pending_review'),
    const Book(id: 'b3', title: 'Berserk', author: 'Kentaro Miura', price: 400, stock: 40),
  ];

  for (final (name, size) in [('phone', const Size(360, 800)), ('desktop', const Size(1100, 900))]) {
    for (final (themeName, theme) in [('light', light), ('dark', dark)]) {
      testWidgets('orders and products render on $name ($themeName)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final screen in [const AdminOrdersScreen(), const AdminProductsScreen()]) {
          await tester.pumpWidget(ProviderScope(
            overrides: [
              adminOrdersProvider.overrideWith((ref) => Stream.value(orders)),
              adminProductsProvider.overrideWith((ref) => Stream.value(books)),
            ],
            child: MaterialApp(theme: theme, home: screen),
          ));
          await tester.pump();
        }
        // The products screen is the one left on screen.
        expect(find.text('Solo Leveling'), findsOneWidget);
        if (name == 'desktop') expect(find.text('STOCK'), findsOneWidget);
      });
    }
  }
}
