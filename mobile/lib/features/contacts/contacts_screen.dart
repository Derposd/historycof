import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/motion.dart';
import 'contacts_providers.dart';
import 'venue.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider).value ?? Venue.fallback;
    final open = ref.watch(openStateProvider);
    final today = mskNow().weekday;
    const h = EdgeInsets.symmetric(horizontal: HcSpace.gutter);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: HcSpace.navInset(context)),
        children: [
          const ScreenTitle('Контакты'),
          Padding(
            padding: h,
            child: FadeSlideIn(
              child: Glass(
                padding: const EdgeInsets.all(HcSpace.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OpenIndicator(state: open, text: describeOpenState(open, mskNow())),
                    const SizedBox(height: HcSpace.l),
                    const SectionLabel('Адрес'),
                    const SizedBox(height: HcSpace.xs),
                    Text(venue.address, style: HcType.serif(size: 26, weight: 600, height: 1.15)),
                    const SizedBox(height: HcSpace.l),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showRouteSheet(context, venue),
                        icon: const Icon(Icons.near_me_outlined, size: 20),
                        label: const Text('Построить маршрут'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: HcSpace.listGap),
          Padding(
            padding: h,
            child: FadeSlideIn(
              index: 1,
              // Связь: телефон, WhatsApp и, если указаны в админке, Telegram и ВКонтакте.
              // Instagram не показываем: компания Meta признана в РФ экстремистской организацией.
              child: Row(
                children: [
                  for (final (i, tile) in [
                    _ActionTile(
                      icon: Icons.call_outlined,
                      label: 'Позвонить',
                      onTap: () => openExternal(Links.call(venue.phone)),
                    ),
                    _ActionTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      onTap: () => openExternal(Links.whatsapp(venue.whatsapp)),
                    ),
                    if (venue.telegram.isNotEmpty)
                      _ActionTile(
                        icon: Icons.send_rounded,
                        label: 'Telegram',
                        onTap: () => openExternal(Links.telegram(venue.telegram)),
                      ),
                    if (venue.vk.isNotEmpty)
                      _ActionTile(
                        icon: Icons.groups_outlined,
                        label: 'ВКонтакте',
                        onTap: () => openExternal(Links.vk(venue.vk)),
                      ),
                  ].indexed) ...[if (i > 0) const SizedBox(width: HcSpace.listGap), Expanded(child: tile)],
                ],
              ),
            ),
          ),
          const SizedBox(height: HcSpace.section),
          const Padding(padding: h, child: SectionLabel('Часы работы')),
          const SizedBox(height: HcSpace.s),
          Padding(
            padding: h,
            child: FadeSlideIn(
              index: 2,
              child: SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: HcSpace.l, vertical: HcSpace.xs),
                child: Column(
                  children: [
                    for (final hrs in [...venue.hours]..sort((a, b) => a.day.compareTo(b.day)))
                      _HoursRow(hours: hrs, isToday: hrs.day == today, isLast: hrs.day == 7),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: HcSpace.section),
          const Padding(padding: h, child: SectionLabel('Телефон')),
          const SizedBox(height: HcSpace.xs),
          Padding(
            padding: h,
            child: Pressable(
              onTap: () => openExternal(Links.call(venue.phone)),
              child: Text(formatPhone(venue.phone), style: HcType.serif(size: 26, weight: 600)),
            ),
          ),
          const SizedBox(height: HcSpace.section),
          Padding(
            padding: h,
            child: SoftCard(
              onTap: () => context.push('/feedback/new'),
              child: Row(
                children: [
                  const IconTile(Icons.edit_note_rounded),
                  const SizedBox(width: HcSpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Обратная связь', style: HcType.serif(size: 21, weight: 600)),
                        const SizedBox(height: 2),
                        Text(
                          'Жалоба, идея или спасибо — ответим в приложении',
                          style: HcType.sans(size: 13, color: HcColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HcColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: HcSpace.section),
          Center(
            child: Text(venue.legalName, style: HcType.sans(size: 12, color: HcColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _OpenIndicator extends StatefulWidget {
  const _OpenIndicator({required this.state, required this.text});

  final OpenState state;
  final String text;

  @override
  State<_OpenIndicator> createState() => _OpenIndicatorState();
}

/// Статус работы; когда открыто, точка мягко «дышит».
class _OpenIndicatorState extends State<_OpenIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_OpenIndicator old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.state.isOpen && !Motion.reduced(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.state.isOpen;
    final color = open ? HcColors.accent : HcColors.terracotta;
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.medium),
        padding: const EdgeInsets.symmetric(horizontal: HcSpace.m, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: open
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5 * (1 - _pulse.value)),
                            blurRadius: 0,
                            spreadRadius: 5 * _pulse.value,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            const SizedBox(width: HcSpace.s),
            Flexible(
              child: Text(
                widget.text,
                style: HcType.sans(size: 13, weight: 600, color: open ? HcColors.accentDark : HcColors.terracotta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: HcSpace.l),
        child: Column(
          children: [
            IconTile(icon, size: 42),
            const SizedBox(height: HcSpace.s),
            Text(label, style: HcType.sans(size: 13, weight: 500)),
          ],
        ),
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.hours, required this.isToday, required this.isLast});

  final DayHours hours;
  final bool isToday;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = HcType.sans(
      size: 15,
      weight: isToday ? 600 : 400,
      color: isToday ? HcColors.text : HcColors.textSecondary,
    );
    final name = weekdayNames[hours.day - 1];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: HcSpace.m),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: HcColors.hairline, width: 0.6)),
      ),
      child: Row(
        children: [
          Text('${name[0].toUpperCase()}${name.substring(1)}', style: style),
          if (isToday) ...[
            const SizedBox(width: HcSpace.s),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.s, vertical: 2),
              decoration: BoxDecoration(
                color: HcColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'сегодня',
                style: HcType.sans(size: 11, weight: 600, color: HcColors.accentDark, height: 1.3),
              ),
            ),
          ],
          const Spacer(),
          Text(hours.isDayOff ? 'выходной' : '${hours.open} – ${hours.close}', style: style),
        ],
      ),
    );
  }
}

void _showRouteSheet(BuildContext context, Venue v) {
  final options = <(String, Uri)>[
    ('Яндекс Карты', Links.yandexMaps(address: v.address, lat: v.lat, lng: v.lng)),
    ('2ГИС', Links.twoGis(address: v.address, lat: v.lat, lng: v.lng)),
    ('Google Maps', Links.googleMaps(address: v.address, lat: v.lat, lng: v.lng)),
    if (defaultTargetPlatform == TargetPlatform.iOS)
      ('Apple Карты', Links.appleMaps(address: v.address, lat: v.lat, lng: v.lng)),
  ];
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(duration: Motion.of(context, Motion.slow), curve: Motion.emphasized),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(HcSpace.m),
      child: Glass(
        radius: 26,
        fill: HcColors.glassFillStrong,
        padding: const EdgeInsets.fromLTRB(HcSpace.s, HcSpace.l, HcSpace.s, HcSpace.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Открыть маршрут в', style: HcType.serif(size: 22, weight: 600)),
            const SizedBox(height: 8),
            for (final (label, uri) in options)
              ListTile(
                title: Text(label, style: HcType.sans(size: 16, weight: 500)),
                trailing: const Icon(Icons.north_east_rounded, size: 18, color: HcColors.textSecondary),
                onTap: () async {
                  Navigator.pop(context);
                  await openExternal(uri);
                },
              ),
          ],
        ),
      ),
    ),
  );
}
