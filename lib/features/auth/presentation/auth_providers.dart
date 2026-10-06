import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/services/db.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => SupabaseAuthRepository());

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The signed-in user's `profiles` row, kept live so streak / badge /
/// completed-count changes reflect immediately across the app.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);

  return watchQuery(Tables.profiles, () async {
    final row = await db.from(Tables.profiles).select().eq('id', uid).maybeSingle();
    return row == null ? null : AppUser.fromRow(row);
  });
});
