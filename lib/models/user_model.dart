class UserModel {
  final int id;
  final String username;
  final String role;
  final bool active;
  final double? lat;
  final double? lng;
  final String? fcmToken;
  /// Prénom(s) complets tels que sur la CNIB.
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? cnibImagePath;
  final String? cnibOcrText;
  final String? cnibNationalId;
  final String? cnibSerial;
  final String? birthDate;
  final String? birthPlace;
  final String? gender;
  final String? profession;
  final String? cnibIssueDate;
  final String? cnibExpiryDate;

  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.active = true,
    this.lat,
    this.lng,
    this.fcmToken,
    this.firstName,
    this.lastName,
    this.phone,
    this.cnibImagePath,
    this.cnibOcrText,
    this.cnibNationalId,
    this.cnibSerial,
    this.birthDate,
    this.birthPlace,
    this.gender,
    this.profession,
    this.cnibIssueDate,
    this.cnibExpiryDate,
  });

  /// Nom affiché dans les listes (identité livreur si renseignée, sinon login).
  String get displayName {
    final f = firstName?.trim() ?? '';
    final l = lastName?.trim() ?? '';
    if (f.isNotEmpty || l.isNotEmpty) {
      return '$f $l'.trim();
    }
    return username;
  }

  String? get displayPhone {
    final p = phone?.trim();
    return (p != null && p.isNotEmpty) ? p : null;
  }

  bool get isDeliveryAgent => role == 'DELIVERY_AGENT';
  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';
  bool get hasDeliveryAccess => isDeliveryAgent || isAdmin;

  factory UserModel.fromSqlite(Map<String, dynamic> row) => UserModel(
        id: row['id'] as int,
        username: row['username'] as String,
        role: row['role'] as String,
        active: (row['active'] as int? ?? 1) == 1,
        lat: row['lat'] != null ? (row['lat'] as num).toDouble() : null,
        lng: row['lng'] != null ? (row['lng'] as num).toDouble() : null,
        fcmToken: row['fcm_token'] as String?,
        firstName: row['first_name'] as String?,
        lastName: row['last_name'] as String?,
        phone: row['phone'] as String?,
        cnibImagePath: row['cnib_image_path'] as String?,
        cnibOcrText: row['cnib_ocr_text'] as String?,
        cnibNationalId: row['cnib_national_id'] as String?,
        cnibSerial: row['cnib_serial'] as String?,
        birthDate: row['birth_date'] as String?,
        birthPlace: row['birth_place'] as String?,
        gender: row['gender'] as String?,
        profession: row['profession'] as String?,
        cnibIssueDate: row['cnib_issue_date'] as String?,
        cnibExpiryDate: row['cnib_expiry_date'] as String?,
      );
}
