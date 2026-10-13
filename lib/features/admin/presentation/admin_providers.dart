import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/book.dart';
import '../../../core/models/store.dart';
import '../../../core/models/store_message.dart';
import '../../../core/models/voucher.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../messages/presentation/message_providers.dart';
import '../data/admin_repository.dart';

/// True only once the signed-in user's `profiles` row has loaded and its
/// `is_admin` flag is set — gates both UI entry points and the route guard.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(appUserProvider).value?.isAdmin ?? false;
});

final adminRepositoryProvider = Provider((ref) => AdminRepository());

final adminProductSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final adminProductsProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  final search = ref.watch(adminProductSearchProvider);
  return ref.watch(adminRepositoryProvider).watchProducts(search: search);
});

final adminOrdersProvider = StreamProvider.autoDispose<List<AdminOrder>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllOrders();
});

final adminVouchersProvider = StreamProvider.autoDispose<List<Voucher>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllVouchers();
});

final adminThreadsProvider = StreamProvider.autoDispose<List<AdminThread>>((ref) {
  return ref.watch(adminRepositoryProvider).watchThreads();
});

final adminStatsProvider = StreamProvider.autoDispose<AdminStats>((ref) {
  return ref.watch(adminRepositoryProvider).watchStats();
});

/// A specific customer's thread, viewed by the admin (RLS lets admins read
/// every thread — see "messages: read own or admin").
final adminThreadMessagesProvider = StreamProvider.autoDispose.family<List<StoreMessage>, String>((ref, uid) {
  return ref.watch(messageRepositoryProvider).watchThread(uid);
});

final adminCustomerProvider = FutureProvider.autoDispose.family<CustomerInfo?, String>((ref, uid) {
  return ref.watch(adminRepositoryProvider).customer(uid);
});

final adminApplicationsProvider = StreamProvider.autoDispose<List<SellerApplication>>((ref) {
  return ref.watch(adminRepositoryProvider).watchApplications();
});

final adminStoresProvider = StreamProvider.autoDispose<List<Store>>((ref) {
  return ref.watch(adminRepositoryProvider).watchStores();
});

final adminListingReviewProvider = StreamProvider.autoDispose<List<ReviewListing>>((ref) {
  return ref.watch(adminRepositoryProvider).watchListingsForReview();
});
