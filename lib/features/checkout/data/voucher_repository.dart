import '../../../core/models/voucher.dart';
import '../../../core/services/db.dart';

class VoucherRepository {
  /// Public, promo-code-style vouchers — no per-user claiming/wallet, any
  /// signed-in shopper can apply an active code at checkout.
  Stream<List<Voucher>> watchActiveVouchers() {
    return watchQuery(Tables.vouchers, () async {
      final rows = await db.from(Tables.vouchers).select().eq('is_active', true).order('created_at');
      return rows.map(Voucher.fromRow).where((v) => !v.isExpired).toList();
    });
  }

  Future<Voucher?> getByCode(String code) async {
    final row =
        await db.from(Tables.vouchers).select().eq('code', code.trim().toUpperCase()).limit(1).maybeSingle();
    return row == null ? null : Voucher.fromRow(row);
  }

  Stream<Voucher?> watchById(String id) {
    return watchQuery(Tables.vouchers, () async {
      final row = await db.from(Tables.vouchers).select().eq('id', id).maybeSingle();
      return row == null ? null : Voucher.fromRow(row);
    });
  }
}
