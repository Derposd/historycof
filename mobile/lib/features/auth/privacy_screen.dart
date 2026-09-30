import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';

/// Документы для гостей: privacy — политика, consent — согласие на обработку ПДн,
/// marketing — согласие на рекламу, loyalty — правила бонусной программы.
typedef LegalDoc = ({String title, String markdown});

final legalDocProvider = FutureProvider.family<LegalDoc, String>((ref, kind) async {
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/legal/$kind', auth: false);
  return (title: json['title'] as String? ?? 'Документ', markdown: json['markdown'] as String);
});

/// Короткие заголовки для верхней панели.
const legalShortTitles = {
  'privacy': 'Политика',
  'consent': 'Согласие на обработку данных',
  'marketing': 'Согласие на рекламу',
  'loyalty': 'Правила бонусной программы',
};

/// Экран юридического документа. Текст приходит с сервера — его можно обновлять без релиза;
/// реквизиты кофейни подставляются из админки.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(legalDocProvider(kind));
    return Scaffold(
      appBar: AppBar(title: Text(legalShortTitles[kind] ?? 'Документ')),
      body: HcBackground(
        child: switch (doc) {
          AsyncData(:final value) => SimpleMarkdown(value.markdown),
          AsyncError(:final error) => ErrorState(error: error, onRetry: () => ref.invalidate(legalDocProvider(kind))),
          _ => const Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
        },
      ),
    );
  }
}

/// Минимальный рендер markdown для юридических текстов: заголовки #/##, списки «- », абзацы.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (final raw in source.split(RegExp(r'\n\s*\n'))) {
      final block = raw.trim();
      if (block.isEmpty) continue;
      if (block.startsWith('# ')) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(block.substring(2), style: HcType.serif(size: 30, weight: 500)),
          ),
        );
      } else if (block.startsWith('## ')) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 6),
            child: Text(block.substring(3), style: HcType.serif(size: 22, weight: 600)),
          ),
        );
      } else if (block.startsWith('- ')) {
        for (final line in block.split('\n')) {
          blocks.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('—  ', style: HcType.sans(color: HcColors.accent)),
                  Expanded(
                    child: Text.rich(_inline(line.replaceFirst(RegExp(r'^-\s*'), '')), style: HcType.sans(size: 15)),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text.rich(_inline(block.replaceAll('\n', ' ')), style: HcType.sans(size: 15, height: 1.55)),
          ),
        );
      }
    }
    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 32),
        children: blocks,
      ),
    );
  }
}

/// **Жирный** текст внутри абзаца.
TextSpan _inline(String text) {
  final parts = text.split('**');
  return TextSpan(
    children: [
      for (var i = 0; i < parts.length; i++)
        TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
    ],
  );
}
