class User {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final int userType;
  final String? avatarUrl;
  final double walletBalance;
  final int accountStatus;
  final String locale;
  final String currency;
  final String? referralCode;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.userType,
    this.avatarUrl,
    required this.walletBalance,
    required this.accountStatus,
    required this.locale,
    required this.currency,
    this.referralCode,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        userType: json['user_type'] as int? ?? 0,
        avatarUrl: json['avatar_url'] as String?,
        walletBalance: double.tryParse(json['wallet_balance']?.toString() ?? '0') ?? 0,
        accountStatus: json['account_status'] as int? ?? 1,
        locale: json['locale'] as String? ?? 'ar',
        currency: json['currency'] as String? ?? 'EGP',
        referralCode: json['referral_code'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
      };

  bool get isDriver => userType == 1;
}