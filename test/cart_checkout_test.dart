import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/book.dart';
import 'package:my_app/core/models/cart_item.dart';
import 'package:my_app/core/theme/app_color_tokens.dart';
import 'package:my_app/core/widgets/primary_button.dart';
import 'package:my_app/features/cart/domain/cart_line.dart';
import 'package:my_app/features/cart/presentation/cart_providers.dart';
import 'package:my_app/features/cart/presentation/cart_screen.dart';

const firstBook = Book(
  id: 'first',
  title: 'First',
  author: 'Author',
  price: 100,
  stock: 5,
);
const secondBook = Book(
  id: 'second',
  title: 'Second',
  author: 'Author',
  price: 200,
  stock: 5,
);

void main() {
  testWidgets('unchecking the first item preserves the second selection', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        cartLinesProvider.overrideWith(
          (_) async => const [
            CartLine(book: firstBook, quantity: 1),
            CartLine(book: secondBook, quantity: 1),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColorTokens.light]),
          home: const CartScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstTile = find.byKey(const ValueKey('first'));
    await tester.tap(
      find
          .descendant(of: firstTile, matching: find.byType(GestureDetector))
          .first,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedCartBookIdsProvider), {'second'});
    await tester.tap(
      find
          .descendant(of: firstTile, matching: find.byType(GestureDetector))
          .first,
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedCartBookIdsProvider), {'first', 'second'});
  });

  for (final stock in [0, 1]) {
    testWidgets(
      'checkout is disabled when selected quantity 2 exceeds stock $stock',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cartLinesProvider.overrideWith(
                (_) async => [
                  CartLine(book: firstBook.copyWith(stock: stock), quantity: 2),
                ],
              ),
              selectedCartBookIdsProvider.overrideWith((_) => {'first'}),
            ],
            child: MaterialApp(
              theme: ThemeData(extensions: const [AppColorTokens.light]),
              home: const CartScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(button.onPressed, isNull);
      },
    );
  }

  test(
    'cart lines observe a new stock value without changing cart quantities',
    () async {
      final books = StreamController<Book?>();
      final container = ProviderContainer(
        overrides: [
          cartItemsProvider.overrideWith(
            (_) => Stream.value(const [CartItem(bookId: 'first', quantity: 2)]),
          ),
          cartBookProvider('first').overrideWith((_) => books.stream),
        ],
      );
      final subscription = container.listen(cartLinesProvider, (_, _) {});
      try {
        final loaded = container.read(cartLinesProvider.future);
        books.add(firstBook);
        expect((await loaded).single.book.stock, 5);
        final changed = Completer<List<CartLine>>();
        final listener = container.listen(cartLinesProvider, (_, next) {
          if (next.valueOrNull?.single.book.stock == 0 &&
              !changed.isCompleted) {
            changed.complete(next.requireValue);
          }
        });
        books.add(firstBook.copyWith(stock: 0));
        final lines = await changed.future.timeout(const Duration(seconds: 3));
        expect(lines.single.quantity, 2);
        expect(lines.single.book.inStock, isFalse);
        listener.close();
      } finally {
        subscription.close();
        container.dispose();
        await books.close();
      }
    },
  );
}
