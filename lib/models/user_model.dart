class UserModel {
  final String id;
  final String mobileNumber;
  final String? name;
  final String? upiMobile;
  final String referralCode;
  final int loyaltyPoints;
  final bool isAdmin;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.mobileNumber,
    this.name,
    this.upiMobile,
    required this.referralCode,
    required this.loyaltyPoints,
    this.isAdmin = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      mobileNumber: json['mobile_number'],
      name: json['name'],
      upiMobile: json['upi_mobile'],
      referralCode: json['referral_code'],
      loyaltyPoints: json['loyalty_points'] ?? 0,
      isAdmin: json['is_admin'] == true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile_number': mobileNumber,
      'name': name,
      'upi_mobile': upiMobile,
      'referral_code': referralCode,
      'loyalty_points': loyaltyPoints,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
