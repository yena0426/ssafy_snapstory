import 'package:snapstory/services/auth/auth_provider.dart';
import 'package:snapstory/services/auth/auth_user.dart';
import 'package:snapstory/services/auth/firebase_auth_provider.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;

  const AuthService(this.provider);

  factory AuthService.firebase() => AuthService(FirebaseAuthProvider());

  @override
  Future<void> initialize() => provider.initialize();

  @override
  Future<AuthUser> createUser({
    required String email,
    required String userName,
    required String password,
  }) =>
      provider.createUser(
        email: email,
        userName: userName,
        password: password,
      );

  @override
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) =>
      provider.login(
        email: email,
        password: password,
      );

  @override
  Future<void> logout() => provider.logout();

  @override
  Future<void> sendEmailVerification() => provider.sendEmailVerification();

  @override
  Future<void> sendPasswordResetEmail({required String email}) => provider.sendPasswordResetEmail(email: email);

  @override
  Future<void> deleteUser({required String email, required String password}) => provider.deleteUser(email: email, password: password);
}
