class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String token;
  final bool hasDefaultCredentials;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.hasDefaultCredentials = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'user',
      token: json['token'] ?? json['access_token'] ?? '',
      hasDefaultCredentials: json['has_default_credentials'] ?? json['hasDefaultCredentials'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
      'has_default_credentials': hasDefaultCredentials,
    };
  }
}
