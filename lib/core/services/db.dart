import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Postgres table names — the schema itself lives in
/// supabase/schema.sql.
abstract final class Tables {
  static const profiles = 'profiles';
  static const books = 'books';
  static const cartItems = 'cart_items';
  static const wishlistItems = 'wishlist_items';
  static const libraryEntries = 'library_entries';
  static const collections = 'collections';
  static const addresses = 'addresses';
  static const vouchers = 'vouchers';
  static const orders = 'orders';
  static const reviews = 'reviews';
  static const notifications = 'notifications';
  static const messages = 'messages';
}

SupabaseClient get db => Supabase.instance.client;

/// Postgres returns timestamps as ISO-8601 strings.
DateTime? parseTimestamp(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// For `date` columns (e.g. books.release_date) — `yyyy-mm-dd`.
String? formatDate(DateTime? value) => value?.toIso8601String().substring(0, 10);

List<String> stringList(Object? value) => value is List ? value.map((e) => e.toString()).toList() : const [];

double toDouble(Object? value, [double fallback = 0]) => value is num ? value.toDouble() : fallback;

int toInt(Object? value, [int fallback = 0]) => value is num ? value.toInt() : fallback;

var _channelCounter = 0;

/// Live query: runs [fetch] now, then again whenever any row of [table]
/// changes (Supabase Realtime), emitting the fresh result each time.
///
/// Re-fetching (rather than patching rows from the change payload, like
/// `.stream()` does) keeps every query shape available — joins, ordering,
/// `or` filters — and stays correct for DELETE events, which Realtime can't
/// filter by column. Every re-fetch still goes through Row Level Security,
/// so a user only ever sees their own rows. Fine at this app's scale.
Stream<T> watchQuery<T>(String table, Future<T> Function() fetch) {
  late final StreamController<T> controller;
  RealtimeChannel? channel;
  Timer? debounce;
  var closed = false;

  Future<void> run() async {
    try {
      final result = await fetch();
      if (!closed) controller.add(result);
    } catch (e, st) {
      if (!closed) controller.addError(e, st);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      run();
      channel = db
          .channel('live:$table:${_channelCounter++}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) {
              // Coalesce bursts (e.g. clearing a whole cart) into one fetch.
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 150), run);
            },
          )
          .subscribe();
    },
    onCancel: () async {
      closed = true;
      debounce?.cancel();
      final c = channel;
      if (c != null) await db.removeChannel(c);
    },
  );
  return controller.stream;
}
