class GuestProfile {
  const GuestProfile({
    required this.id,
    required this.phone,
    this.name,
    this.birthday,
    this.pushNewsEnabled = true,
    this.consentRequired = false,
  });

  final String id;

  /// E.164: +79604316223
  final String phone;
  final String? name;

  /// YYYY-MM-DD
  final String? birthday;
  final bool pushNewsEnabled;

  /// Политика ПДн обновилась — нужно повторно получить согласие.
  final bool consentRequired;

  factory GuestProfile.fromJson(Map<String, dynamic> j) => GuestProfile(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String?,
        birthday: j['birthday'] as String?,
        pushNewsEnabled: j['pushNewsEnabled'] as bool? ?? true,
        consentRequired: j['consentRequired'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'birthday': birthday,
        'pushNewsEnabled': pushNewsEnabled,
        'consentRequired': consentRequired,
      };
}

class OtpRequestResult {
  const OtpRequestResult({required this.resendInSec, required this.isNewUser});

  final int resendInSec;

  /// Новый гость — на экране кода нужно согласие на обработку ПДн.
  final bool isNewUser;

  factory OtpRequestResult.fromJson(Map<String, dynamic> j) => OtpRequestResult(
        resendInSec: (j['resendInSec'] as num?)?.toInt() ?? 60,
        isNewUser: j['isNewUser'] as bool? ?? false,
      );
}
