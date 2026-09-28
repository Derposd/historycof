import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';

final privacyPolicyProvider = FutureProvider<String>((ref) async {
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/legal/privacy', auth: false);
  return json['markdown'] as String;
});

/// Политика обработки ПДн. Текст приходит с сервера — его можно обновлять без релиза.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(privacyPolicyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Конфиденциальность')),
      body: HcBackground(
        child: switch (policy) {
          AsyncData(:final value) => SimpleMarkdown(value),
          AsyncError(:final error) => ErrorState(error: error, onRetry: () => ref.invalidate(privacyPolicyProvider)),
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
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(block.substring(2), style: HcType.serif(size: 30, weight: 500)),
        ));
      } else if (block.startsWith('## ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(block.substring(3), style: HcType.serif(size: 22, weight: 600)),
        ));
      } else if (block.startsWith('- ')) {
        for (final line in block.split('\n')) {
          blocks.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('—  ', style: HcType.sans(color: HcColors.accent)),
                Expanded(child: Text(line.replaceFirst(RegExp(r'^-\s*'), ''), style: HcType.sans(size: 15))),
              ],
            ),
          ));
        }
      } else {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(block.replaceAll('\n', ' '), style: HcType.sans(size: 15, height: 1.55)),
        ));
      }
    }
    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(22, 8, 22, MediaQuery.paddingOf(context).bottom + 32),
        children: blocks,
      ),
    );
  }
}
