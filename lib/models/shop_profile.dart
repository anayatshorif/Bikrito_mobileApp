class ShopProfile {
  const ShopProfile({
    required this.owner,
    required this.shop,
    required this.phone,
    this.email = '',
    this.userId = '',
    this.pinHash = '',
    this.logoPath,
    this.logoData,
  });

  final String email;
  final String userId;
  final String pinHash;
  final String owner;
  final String shop;
  final String phone;
  final String? logoPath;
  final String? logoData;

  Map<String, dynamic> toJson() => {
    'email': email,
    'user_id': userId,
    'pin_hash': pinHash,
    'owner': owner,
    'shop': shop,
    'phone': phone,
    'logo_path': logoPath,
    'logo_data': logoData,
  };

  factory ShopProfile.fromJson(Map<String, dynamic> json) => ShopProfile(
    email: (json['email'] ?? '') as String,
    userId: (json['user_id'] ?? json['userId'] ?? '') as String,
    pinHash: (json['pin_hash'] ?? json['pinHash'] ?? '') as String,
    owner: json['owner'] as String? ?? '',
    shop: json['shop'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    logoPath: (json['logo_path'] ?? json['logoPath']) as String?,
    logoData: (json['logo_data'] ?? json['logoData']) as String?,
  );
}
