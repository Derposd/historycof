import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import 'feedback.dart';

class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myFeedbackProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Мои обращения')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/feedback/new'),
        backgroundColor: HcColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Написать'),
      ),
      body: HcBackground(
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: RefreshIndicator(
            key: ValueKey(list.hasValue),
            color: HcColors.accent,
            onRefresh: () => ref.refresh(myFeedbackProvider.future),
            child: switch (list) {
              AsyncData(:final value) when value.isEmpty => ListView(
                children: const [
                  EmptyState(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Обращений пока нет',
                    subtitle: 'Здесь появятся ваши сообщения и ответы кофейни',
                  ),
                ],
              ),
              AsyncData(:final value) => ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  HcSpace.gutter,
                  HcSpace.s,
                  HcSpace.gutter,
                  MediaQuery.paddingOf(context).bottom + 96,
                ),
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(height: HcSpace.listGap),
                itemBuilder: (_, i) => FadeSlideIn(
                  index: i,
                  child: _FeedbackCard(entry: value[i]),
                ),
              ),
              AsyncError(:final error) => ErrorState(error: error, onRetry: () => ref.invalidate(myFeedbackProvider)),
              _ => const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
            },
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.entry});

  final FeedbackEntry entry;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.all(HcSpace.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SectionLabel(
                entry.type.label,
                color: entry.type == FeedbackType.complaint ? HcColors.terracotta : HcColors.accentDark,
              ),
              const Spacer(),
              StatusPill(status: entry.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(entry.message, style: HcType.sans(size: 15)),
          const SizedBox(height: 8),
          Text(formatDateTimeShort(entry.createdAt), style: HcType.sans(size: 12.5, color: HcColors.textSecondary)),
          if (entry.reply != null) ...[
            const SizedBox(height: 14),
            AccentNote(
              color: HcColors.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Ответ кофейни', color: HcColors.accentDark),
                  const SizedBox(height: HcSpace.xs),
                  Text(entry.reply!, style: HcType.sans(size: 15)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final FeedbackStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      FeedbackStatus.sent => HcColors.textSecondary,
      FeedbackStatus.viewed => HcColors.gold,
      FeedbackStatus.answered => HcColors.accent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.label,
        style: HcType.sans(
          size: 11.5,
          color: status == FeedbackStatus.viewed ? HcColors.text : color,
          weight: 600,
          height: 1.2,
        ),
      ),
    );
  }
}
