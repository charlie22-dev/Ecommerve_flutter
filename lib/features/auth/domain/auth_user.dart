import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// The signed-in account, independent of the auth backend's own user type
/// (screens read `authStateProvider.value?.uid`).
class AuthUser extends Equatable {
  const AuthUser({required this.uid, required this.email, this.displayName = '', this.photoUrl});

  factory AuthUser.fromSupabase(User user) {
    final meta = user.userMetadata ?? const {};
    return AuthUser(
      uid: user.id,
      email: user.email ?? '',
      displayName: (meta['display_name'] ?? meta['full_name'] ?? meta['name'] ?? '') as String,
      photoUrl: meta['avatar_url'] as String?,
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  @override
  List<Object?> get props => [uid, email];
}
