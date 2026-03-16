enum UserRole {
  admin,
  cashier,
}

/// Uygulama içinde kullanılan basit kullanıcı modeli.
///
/// Firebase Auth'tan gelen kullanıcı + aktif firma üyeliğinden gelen rol ile üretilir.
class User {
  final String id;
  final String email;
  final UserRole role;

  const User({
    required this.id,
    required this.email,
    required this.role,
  });
}