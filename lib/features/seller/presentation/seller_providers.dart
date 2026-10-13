import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/models/seller_order.dart';
import '../../../core/models/store.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/seller_repository.dart';

final sellerRepositoryProvider = Provider((ref) => SellerRepository());

/// The signed-in user's store — null until an admin approves them.
final myStoreProvider = StreamProvider<Store?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(sellerRepositoryProvider).watchMyStore(uid);
});

final mySellerApplicationProvider = StreamProvider.autoDispose<SellerApplication?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(sellerRepositoryProvider).watchMyApplication(uid);
});

final myListingsProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  final storeId = ref.watch(myStoreProvider).value?.id;
  if (storeId == null) return Stream.value(const []);
  return ref.watch(sellerRepositoryProvider).watchListings(storeId);
});

final myStoreOrdersProvider = StreamProvider.autoDispose<List<SellerOrder>>((ref) {
  final storeId = ref.watch(myStoreProvider).value?.id;
  if (storeId == null) return Stream.value(const []);
  return ref.watch(sellerRepositoryProvider).watchOrders(storeId);
});

/// The rate this store pays per sale (its own rate, else the platform's).
final myCommissionRateProvider = FutureProvider.autoDispose<double>((ref) async {
  final store = ref.watch(myStoreProvider).value;
  return store?.commissionRate ?? await ref.watch(sellerRepositoryProvider).platformCommissionRate();
});

final orderShipmentsProvider = StreamProvider.autoDispose.family<List<SellerOrder>, String>((ref, orderId) {
  return ref.watch(sellerRepositoryProvider).watchShipments(orderId);
});
