import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/db.dart';

/// Updates the parts of a profile the Edit Profile screen owns: display
/// name and avatar. Writes the `profiles` row the app reads from, and keeps
/// the auth user's metadata in sync (shown in the Supabase Auth dashboard).
class ProfileRepository {
  Future<void> updateProfile({required String displayName, String? photoUrl}) async {
    final user = db.auth.currentUser;
    if (user == null) return;

    await db.from(Tables.profiles).update({
      'display_name': displayName,
      'photo_url': ?photoUrl,
    }).eq('id', user.id);

    await db.auth.updateUser(UserAttributes(data: {
      'display_name': displayName,
      'avatar_url': ?photoUrl,
    }));
  }

  /// Deletes the auth account via the `delete_my_account` Postgres function
  /// (the anon key can't call the auth admin API). Every user-owned row —
  /// profile, cart, library, orders… — goes with it (ON DELETE CASCADE).
  Future<void> deleteAccount() async {
    await db.rpc('delete_my_account');
    await db.auth.signOut();
  }
}
