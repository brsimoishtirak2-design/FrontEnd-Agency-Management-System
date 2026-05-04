import '../../../shared/models/user.dart';

/// Response shape from POST /api/auth/login.
///
/// Hand-written (no freezed) due to build_runner/path_provider AOT collision in
/// late-2025 Flutter. Convert to freezed once build_runner 3.x lands.
class LoginResponse {
  final String token;
  final User user;

  const LoginResponse({
    required this.token,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
