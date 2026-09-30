import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/providers.dart';

/// Сообщение в чате гостя с кофейней.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromStaff,
    required this.text,
    required this.createdAt,
    this.readAt,
  });

  final String id;

  /// true — написала кофейня, false — гость.
  final bool fromStaff;
  final String text;
  final DateTime createdAt;
  final DateTime? readAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    fromStaff: j['fromStaff'] as bool,
    text: j['text'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
    readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String).toLocal(),
  );
}

class ChatRepository {
  ChatRepository(this._ref);

  final Ref _ref;

  Future<ChatMessage> send(String text) async {
    final json = await _ref.read(apiClientProvider).post<Map<String, dynamic>>('/chat', data: {'text': text.trim()});
    return ChatMessage.fromJson(json);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(ChatRepository.new);

/// Переписка (только для вошедших гостей). Загрузка отмечает ответы кофейни прочитанными.
final chatThreadProvider = FutureProvider.autoDispose<List<ChatMessage>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const [];
  final list = await ref.watch(apiClientProvider).get<List<dynamic>>('/chat');
  return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
});

/// Непрочитанные ответы кофейни — точка на плитке «Чат».
final chatUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  if (!ref.watch(isSignedInProvider)) return 0;
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/chat/unread');
  return (json['count'] as num?)?.toInt() ?? 0;
});
