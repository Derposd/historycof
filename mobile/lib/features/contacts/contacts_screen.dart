import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import 'contacts_providers.dart';
import 'venue.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueProvider).value ?? Venue.fallback;
    final open = ref.watch(openStateProvider);
    final today = mskNow().weekday;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 110),
        children: [
          const ScreenTitle('Контакты', overline: 'Как нас найти'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Glass(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OpenIndicator(state: open, text: describeOpenState(open, mskNow())),
                  const SizedBox(height: 16),
                  const CapsLabel('Адрес'),
                  const SizedBox(height: 6),
                  Text(venue.address, style: HcType.serif(size: 26, weight: 500)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showRouteSheet(context, venue),
                      icon: const Icon(Icons.near_me_outlined, size: 20),
                      label: const Text('Маршрут'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.call_outlined,
                    label: 'Позвонить',
                    onTap: () => openExternal(Links.call(venue.phone)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Написать',
                    onTap: () => openExternal(Links.whatsapp(venue.whatsapp)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.photo_camera_outlined,
                    label: 'Instagram',
                    onTap: () => openExternal(Links.instagram(venue.instagram)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: CapsLabel('Часы работы')),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  for (final h in [...venue.hours]..sort((a, b) => a.day.compareTo(b.day)))
                    _HoursRow(hours: h, isToday: h.day == today, isLast: h.day == 7),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: CapsLabel('Телефон')),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: GestureDetector(
              onTap: () => openExternal(Links.call(venue.phone)),
              child: Text(formatPhone(venue.phone), style: HcType.serif(size: 26, weight: 500)),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SoftCard(
              onTap: () => context.push('/feedback/new'),
              child: Row(
                children: [
                  const RoundOutlineIcon(Icons.edit_note_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Обратная связь', style: HcType.serif(size: 21, weight: 600)),
                        Text(
                          'Жалоба, предложение или спасибо — мы читаем каждое сообщение',
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
          const SizedBox(height: 28),
          Center(child: Text(venue.legalName, style: HcType.sans(size: 12, color: HcColors.textSecondary))),
        ],
      ),
    );
  }
}

class _OpenIndicator extends StatelessWidget {
  const _OpenIndicator({required this.state, required this.text});

  final OpenState state;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = state.isOpen ? HcColors.accent : HcColors.terracotta;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: HcType.sans(size: 13, weight: 500, color: state.isOpen ? HcColors.accentDark : HcColors.terracotta),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            RoundOutlineIcon(icon, size: 42),
            const SizedBox(height: 8),
            Text(label.toUpperCase(), style: HcType.caps(size: 10.5, color: HcColors.text)),
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
    final style = HcType.sans(size: 15, weight: isToday ? 600 : 400, color: isToday ? HcColors.text : HcColors.textSecondary);
    final name = weekdayNames[hours.day - 1];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: HcColors.hairline, width: 0.6))),
      child: Row(
        children: [
          Text('${name[0].toUpperCase()}${name.substring(1)}', style: style),
          if (isToday) ...[
            const SizedBox(width: 8),
            const CapsLabel('сегодня', color: HcColors.accentDark, size: 9.5),
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
    builder: (context) => Padding(
      padding: const EdgeInsets.all(12),
      child: Glass(
        radius: 26,
        fill: HcColors.glassFillStrong,
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
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
