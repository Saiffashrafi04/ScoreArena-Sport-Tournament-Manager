enum UserRole { organizer, viewer }

class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  // Convert UserRole to string for Firestore
  static String roleToString(UserRole role) {
    return role.toString().split('.').last; // 'organizer' or 'viewer'
  }

  // Convert string from Firestore to UserRole
  static UserRole stringToRole(String roleStr) {
    return UserRole.values.firstWhere(
      (role) => role.toString().split('.').last == roleStr,
      orElse: () => UserRole.viewer, // default to viewer
    );
  }

  // Convert UserModel to Firestore JSON
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'name': name,
    'role': roleToString(role),
    'createdAt': createdAt.toIso8601String(),
  };

  // Create UserModel from Firestore JSON
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'] ?? '',
    email: json['email'] ?? '',
    name: json['name'] ?? '',
    role: stringToRole(json['role'] ?? 'viewer'),
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
  );

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, name: $name, role: $role)';
}
