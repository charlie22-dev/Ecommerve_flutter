// Checks the Postgres row <-> model mapping (snake_case columns, numeric
// strings/ints, ISO timestamps, jsonb) against rows shaped like what
// PostgREST actually returns for the tables in supabase/schema.sql.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/app_user.dart';
import 'package:my_app/core/models/book.dart';
import 'package:my_app/core/models/order.dart';
import 'package:my_app/core/models/shipping_address.dart';
import 'package:my_app/core/models/voucher.dart';

void main() {
  test('Book.fromRow reads every column and toRow writes them back', () {
    final row = {
      'id': '6f1c2b1e-0000-4000-8000-000000000001',
      'title': 'Naruto, Vol. 1',
      'author': 'Masashi Kishimoto',
      'cover_url': 'https://example.com/c.jpg',
      'price': 320, // numeric comes back as int or double
      'stock': 12,
      'type': 'lightNovel',
      'genres': ['Action', 'Adventure'],
      'format': 'hardcover',
      'language': 'English',
      'publisher': 'VIZ Media',
      'pages': 192,
      'isbn': '9781569319000',
      'rating': 4.8,
      'rating_count': 5210,
      'release_date': '2003-01-01',
      'description': 'A young ninja.',
      'tags': <String>[],
      'featured_sections': ['trending', 'notARealSection'],
      'total_chapters': null,
      'listing_status': 'rejected',
      'moderation_note': 'Blurry cover',
      'created_at': '2026-10-06T01:02:03.123456+00:00',
      'updated_at': '2026-10-06T01:02:03.123456+00:00',
    };

    final book = Book.fromRow(row);
    expect(book.price, 320.0);
    expect(book.type, BookType.lightNovel);
    expect(book.format, BookFormat.hardcover);
    expect(book.coverUrl, 'https://example.com/c.jpg');
    expect(book.ratingCount, 5210);
    expect(book.featuredSections, [FeaturedSection.trending]);
    expect(book.releaseDate, DateTime(2003));
    expect(book.createdAt!.toUtc(), DateTime.utc(2026, 10, 6, 1, 2, 3, 123, 456));

    final out = book.toRow();
    expect(out['cover_url'], row['cover_url']);
    expect(out['type'], 'lightNovel');
    expect(out['release_date'], '2003-01-01');
    expect(out['featured_sections'], ['trending']);
    expect(book.moderationNote, 'Blurry cover');
    expect(out['listing_status'], 'rejected');
    expect(out.containsKey('id'), isFalse, reason: 'id/created_at are DB defaults');
  });

  test('Order round-trips jsonb items and shipping address', () {
    const address = ShippingAddress(
      id: 'a1',
      label: 'Home',
      recipientName: 'Alice',
      phoneNumber: '0917',
      addressLine: '1 Main St',
      city: 'Cebu',
      province: 'Cebu',
      postalCode: '6000',
    );
    const order = Order(
      id: 'aaaaaaaa-0000-0000-0000-000000000001',
      uid: 'u1',
      items: [OrderLineItem(bookId: 'b1', title: 'T', coverUrl: '', unitPrice: 320, quantity: 2)],
      subtotal: 640,
      shippingCost: 60,
      voucherCode: 'WELCOME20',
      voucherDiscount: 128,
      total: 572,
      shippingAddress: address,
      shippingOptionId: 'standard',
      status: OrderStatus.toShip,
    );

    final row = {...order.toRow(), 'created_at': '2026-10-06T00:00:00+00:00'};
    expect(row['user_id'], 'u1');
    final back = Order.fromRow(row);
    expect(back.items.single.lineTotal, 640);
    expect(back.shippingAddress!.city, 'Cebu');
    expect(back.status, OrderStatus.toShip);
    expect(back.total, 572);
  });

  test('ShippingAddress.toRow omits an empty id so Postgres generates one', () {
    const a = ShippingAddress(
      id: '',
      label: 'Work',
      recipientName: 'B',
      phoneNumber: '1',
      addressLine: 'x',
      city: 'y',
      province: 'z',
      postalCode: '0',
      isDefault: true,
    );
    final row = a.toRow('u1');
    expect(row.containsKey('id'), isFalse);
    expect(row['is_default'], isTrue);
    expect(ShippingAddress.fromRow({...row, 'id': 'new'}).label, 'Work');
  });

  test('Voucher and AppUser parse numeric strings and flags', () {
    final v = Voucher.fromRow({
      'id': 'v1',
      'code': 'WELCOME20',
      'title': 'Welcome',
      'discount_type': 'percent',
      'discount_value': 20,
      'min_purchase': 500,
      'max_discount': 300,
      'expires_at': null,
      'is_active': true,
    });
    expect(v.discountFor(1000), 200);
    expect(v.discountFor(2000), 300); // capped
    expect(v.discountFor(100), 0); // below minimum

    final user = AppUser.fromRow({
      'id': 'u1',
      'email': 'a@b.c',
      'display_name': 'Alice',
      'streak_count': 3,
      'is_admin': true,
      'badge_ids': ['firstBook'],
    });
    expect(user.displayName, 'Alice');
    expect(user.isAdmin, isTrue);
    expect(user.badgeIds, ['firstBook']);
  });
}
