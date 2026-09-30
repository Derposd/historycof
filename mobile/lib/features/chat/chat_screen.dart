import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/motion.dart';
import 'chat.dart';

/// Чат с кофейней: гость пишет — сообщение приходит в админку, ответ сотрудника появляется здесь.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  /// Пока экран открыт, подтягиваем новые сообщения.
  static const _poll = Duration(seconds: 5);

  final _text = TextEditingController();
  final _pending = <String>[];
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_poll, (_) {
      if (ref.read(isSignedInProvider)) ref.invalidate(chatThreadProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _pending.add(text);
      _text.clear();
    });
    try {
      await ref.read(chatRepositoryProvider).send(text);
      ref.invalidate(chatThreadProvider);
      await ref.read(chatThreadProvider.future);
    } catch (e) {
      if (mounted) {
        _text.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Не удалось отправить. Проверьте интернет')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pending.remove(text);
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    // Ответы кофейни прочитаны — гасим точку на плитке «Чат»
    ref.listen(chatThreadProvider, (_, next) {
      if (next.hasValue) ref.invalidate(chatUnreadProvider);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Чат с кофейней')),
      body: HcBackground(child: signedIn ? _thread(context) : _signIn(context)),
    );
  }

  Widget _signIn(BuildContext context) => Center(
    child: EmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Напишите нам',
      subtitle: 'Войдите по номеру телефона — так мы сможем ответить вам здесь, в приложении',
      action: FilledButton(onPressed: () => context.push('/login'), child: const Text('Войти')),
    ),
  );

  Widget _thread(BuildContext context) {
    final thread = ref.watch(chatThreadProvider);
    final messages = thread.value;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final Widget list;
    if (messages == null) {
      list = thread.hasError
          ? ErrorState(error: thread.error!, onRetry: () => ref.invalidate(chatThreadProvider))
          : const Center(child: CircularProgressIndicator(strokeWidth: 1.6));
    } else if (messages.isEmpty && _pending.isEmpty) {
      list = const Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Напишите нам',
            subtitle: 'Вопрос, пожелание или бронь столика — ответим здесь же, обычно в часы работы кофейни',
          ),
        ),
      );
    } else {
      // Новые сообщения внизу: список перевёрнут, поэтому он сам держится у последнего
      final items = <Widget>[];
      for (var i = 0; i < messages.length; i++) {
        final m = messages[i];
        if (i == 0 || !_sameDay(messages[i - 1].createdAt, m.createdAt)) items.add(_DayLabel(m.createdAt));
        items.add(_Bubble(key: ValueKey(m.id), message: m));
      }
      for (final p in _pending) {
        items.add(_Bubble(key: ValueKey('pending-$p'), message: null, pendingText: p));
      }
      final reversed = items.reversed.toList();
      list = ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.m, HcSpace.gutter, HcSpace.m),
        itemCount: reversed.length,
        itemBuilder: (_, i) => reversed[i],
      );
    }

    return Column(
      children: [
        Expanded(child: list),
        Container(
          padding: EdgeInsets.fromLTRB(HcSpace.gutter - 4, HcSpace.s, HcSpace.s, HcSpace.s + bottom),
          decoration: const BoxDecoration(
            color: HcColors.glassFillStrong,
            border: Border(top: BorderSide(color: HcColors.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Сообщение', counterText: ''),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: HcSpace.s),
              IconButton.filled(
                tooltip: 'Отправить',
                onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: HcColors.accentDark,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.day);

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final text = _sameDay(day, now)
        ? 'Сегодня'
        : _sameDay(day, now.subtract(const Duration(days: 1)))
        ? 'Вчера'
        : DateFormat('d MMMM', 'ru').format(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HcSpace.s),
      child: Center(
        child: Text(text, style: HcType.sans(size: 12, color: HcColors.textSecondary)),
      ),
    );
  }
}

/// Пузырь сообщения. Свои — справа, зелёные; ответы кофейни — слева, светлые.
class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, this.pendingText});

  final ChatMessage? message;
  final String? pendingText;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m == null || !m.fromStaff;
    final text = m?.text ?? pendingText!;
    final String meta;
    if (m == null) {
      meta = 'отправляется…';
    } else {
      final time = DateFormat('HH:mm').format(m.createdAt);
      meta = mine ? '$time · ${m.readAt != null ? 'прочитано' : 'доставлено'}' : time;
    }
    final fg = mine ? Colors.white : HcColors.text;
    return FadeSlideIn(
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
            decoration: BoxDecoration(
              color: mine ? HcColors.accentDark.withValues(alpha: m == null ? 0.7 : 1) : HcColors.glassFillStrong,
              border: mine ? null : Border.all(color: HcColors.hairline),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 6),
                bottomRight: Radius.circular(mine ? 6 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(text, style: HcType.sans(size: 15, color: fg, height: 1.35)),
                ),
                const SizedBox(height: 3),
                Text(meta, style: HcType.sans(size: 11, color: fg.withValues(alpha: 0.65))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
