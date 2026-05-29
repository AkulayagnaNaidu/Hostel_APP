class AuthUser {
  final String id;
  final String? name;
  final String? email;
  final String role;

  AuthUser({
    required this.id,
    this.name,
    this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'TENANT',
    );
  }
}
