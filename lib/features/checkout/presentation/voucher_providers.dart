import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/voucher.dart';
import '../data/voucher_repository.dart';

final voucherRepositoryProvider = Provider((ref) => VoucherRepository());

final activeVouchersProvider = StreamProvider<List<Voucher>>((ref) {
  return ref.watch(voucherRepositoryProvider).watchActiveVouchers();
});

final voucherByIdProvider = StreamProvider.family<Voucher?, String>((ref, id) {
  return ref.watch(voucherRepositoryProvider).watchById(id);
});

/// The voucher applied to the current cart/checkout session (client-side
/// only — cleared whenever the app restarts, same as the cart's local UI
/// state elsewhere).
final appliedVoucherProvider = StateProvider<Voucher?>((ref) => null);
