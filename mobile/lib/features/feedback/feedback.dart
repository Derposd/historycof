import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/providers.dart';

enum FeedbackType {
  complaint('complaint', 'Жалоба'),
  suggestion('suggestion', 'Предложение'),
  thanks('thanks', 'Благодарность');

  const FeedbackType(this.code, this.label);

  final String code;
  final String label;

  static FeedbackType fromCode(String c) => values.firstWhere((t) => t.code == c, orElse: () => complaint);
}

enum FeedbackStatus {
  sent('sent', 'Отправлено'),
  viewed('viewed', 'Просмотрено'),
  answered('answered', 'Отвечено');

  const FeedbackStatus(this.code, this.label);

  final String code;
  final String label;

  static FeedbackStatus fromCode(String c) => values.firstWhere((s) => s.code == c, orElse: () => sent);
}

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
    this.photoUrl,
    this.reply,
    this.answeredAt,
  });

  final String id;
  final FeedbackType type;
  final String message;
  final String? photoUrl;
  final FeedbackStatus status;
  final String? reply;
  final DateTime createdAt;
  final DateTime? answeredAt;

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
    id: j['id'] as String,
    type: FeedbackType.fromCode(j['type'] as String),
    message: j['message'] as String,
    photoUrl: j['photoUrl'] as String?,
    status: FeedbackStatus.fromCode(j['status'] as String),
    reply: j['reply'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    answeredAt: j['answeredAt'] == null ? null : DateTime.parse(j['answeredAt'] as String),
  );
}

class FeedbackRepository {
  FeedbackRepository(this._ref);

  final Ref _ref;

  Future<FeedbackEntry> submit({
    required FeedbackType type,
    required String message,
    String? contactPhone,
    String? photoPath,
  }) async {
    final form = FormData.fromMap({
      'type': type.code,
      'message': message.trim(),
      if (contactPhone != null && contactPhone.isNotEmpty) 'contactPhone': contactPhone,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath, contentType: _imageType(photoPath)),
    });
    final json = await _ref.read(apiClientProvider).post<Map<String, dynamic>>('/feedback', data: form);
    return FeedbackEntry.fromJson(json);
  }
}

/// image_picker обычно отдаёт JPEG, но с Android может прийти PNG/WEBP —
/// сервер всё равно перекодирует картинку в JPEG.
DioMediaType _imageType(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'png' => DioMediaType('image', 'png'),
    'webp' => DioMediaType('image', 'webp'),
    _ => DioMediaType('image', 'jpeg'),
  };
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(FeedbackRepository.new);

/// Мои обращения (только для вошедших гостей).
final myFeedbackProvider = FutureProvider.autoDispose<List<FeedbackEntry>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const [];
  final list = await ref.watch(apiClientProvider).get<List<dynamic>>('/feedback/mine');
  return list.map((e) => FeedbackEntry.fromJson(e as Map<String, dynamic>)).toList();
});
