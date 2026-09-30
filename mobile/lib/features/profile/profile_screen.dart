import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/guest_profile.dart';
import '../../core/config.dart';
import '../../core/push/push_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/motion.dart';
import '../contacts/contacts_providers.dart';
import '../contacts/venue.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).value;
    final venue = ref.watch(venueProvider).value ?? Venue.fallback;
    const h = EdgeInsets.symmetric(horizontal: HcSpace.gutter);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: HcSpace.navInset(context)),
        children: [
          const ScreenTitle('Профиль'),
          if (AppConfig.demo)
            Padding(
              padding: const EdgeInsets.fromLTRB(HcSpace.gutter, 0, HcSpace.gutter, HcSpace.listGap),
              child: SoftCard(
                padding: const EdgeInsets.all(HcSpace.l),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 20, color: HcColors.textSecondary),
                    const SizedBox(width: HcSpace.m),
                    Expanded(
                      child: Text(
                        'Демо-версия: сервер кофейни ещё не подключён, данные примерные и не сохраняются.',
                        style: HcType.sans(size: 13, color: HcColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: h,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.medium),
              child: profile == null
                  ? const _SignInCard(key: ValueKey('signin'))
                  : _ProfileCard(key: ValueKey(profile.id), profile: profile),
            ),
          ),
          const SizedBox(height: HcSpace.section),
          const Padding(padding: h, child: SectionLabel('Обратная связь')),
          const SizedBox(height: HcSpace.s),
          _Group(
            children: [
              _Row(
                icon: Icons.edit_note_rounded,
                title: 'Написать нам',
                subtitle: 'Жалоба, идея или спасибо',
                onTap: () => context.push('/feedback/new'),
              ),
              if (profile != null)
                _Row(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Мои обращения',
                  onTap: () => context.push('/feedback/mine'),
                ),
            ],
          ),
          if (profile != null) ...[
            const SizedBox(height: HcSpace.section),
            const Padding(padding: h, child: SectionLabel('Уведомления')),
            const SizedBox(height: HcSpace.s),
            _Group(children: [_PushToggle(profile: profile)]),
          ],
          const SizedBox(height: HcSpace.section),
          const Padding(padding: h, child: SectionLabel('Документы')),
          const SizedBox(height: HcSpace.s),
          _Group(
            children: [
              _Row(
                icon: Icons.shield_outlined,
                title: 'Политика обработки персональных данных',
                onTap: () => context.push('/legal/privacy'),
              ),
              _Row(
                icon: Icons.fact_check_outlined,
                title: 'Согласие на обработку данных',
                onTap: () => context.push('/legal/consent'),
              ),
              _Row(
                icon: Icons.campaign_outlined,
                title: 'Согласие на рекламу',
                onTap: () => context.push('/legal/marketing'),
              ),
              _Row(
                icon: Icons.loyalty_outlined,
                title: 'Правила бонусной программы',
                onTap: () => context.push('/legal/loyalty'),
              ),
            ],
          ),
          const SizedBox(height: HcSpace.section),
          const Padding(padding: h, child: SectionLabel('О приложении')),
          const SizedBox(height: HcSpace.s),
          _Group(
            children: [
              _Row(
                icon: Icons.article_outlined,
                title: 'Лицензии',
                subtitle: 'Шрифты и открытые библиотеки',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'History Coffee',
                  applicationLegalese: venue.legalName,
                  applicationIcon: const Padding(padding: EdgeInsets.all(HcSpace.s), child: HcMonogram(size: 48)),
                ),
              ),
              if (profile != null) ...[
                _Row(icon: Icons.logout_rounded, title: 'Выйти', onTap: () => _confirmLogout(context, ref)),
                _Row(
                  icon: Icons.delete_outline_rounded,
                  title: 'Удалить аккаунт',
                  color: HcColors.terracotta,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ],
          ),
          const SizedBox(height: HcSpace.section),
          // Сведения о продавце (ЗоЗПП, ст. 9) и возрастная категория (436-ФЗ)
          Center(
            child: Text(
              [
                'Продавец: ${venue.legalName}',
                if (venue.inn.isNotEmpty) 'ИНН ${venue.inn}',
                if (venue.ogrn.isNotEmpty) '${venue.ogrn.length == 15 ? 'ОГРНИП' : 'ОГРН'} ${venue.ogrn}',
                if (venue.legalAddress.isNotEmpty) venue.legalAddress,
                'Кофейня: ${venue.address}',
                '0+',
              ].join('\n'),
              textAlign: TextAlign.center,
              style: HcType.sans(size: 12, color: HcColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Бонусы сохранятся — они привязаны к номеру телефона.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Выйти')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(pushServiceProvider).unregisterDevice();
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Мы удалим ваш номер, имя и историю в приложении. Бонусный счёт в кассовой системе кофейни '
          'сохранится — чтобы удалить и его, напишите нам.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: HcColors.terracotta),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (context.mounted) showHcSnack(context, 'Аккаунт удалён');
    } catch (e) {
      if (context.mounted) showHcSnack(context, ApiException.messageOf(e));
    }
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.all(HcSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(Icons.person_outline_rounded, size: 56),
          const SizedBox(height: HcSpace.l),
          Text('Войдите по номеру', style: HcType.serif(size: 28, weight: 600)),
          const SizedBox(height: HcSpace.s),
          Text(
            'Бонусная карта, история операций и ответы на ваши обращения — в одном месте.',
            style: HcType.sans(color: HcColors.textSecondary),
          ),
          const SizedBox(height: HcSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => context.push('/login'), child: const Text('Войти')),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({super.key, required this.profile});

  final GuestProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasName = profile.name?.isNotEmpty ?? false;
    return Glass(
      padding: const EdgeInsets.all(HcSpace.card),
      onTap: () => _editName(context, ref),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: HcColors.accent.withValues(alpha: 0.15),
            ),
            child: Text(
              hasName ? profile.name!.characters.first.toUpperCase() : 'H',
              style: HcType.serif(size: 28, weight: 600, color: HcColors.accentDark),
            ),
          ),
          const SizedBox(width: HcSpace.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasName ? profile.name! : 'Гость', style: HcType.serif(size: 24, weight: 600)),
                const SizedBox(height: 2),
                Text(formatPhone(profile.phone), style: HcType.sans(color: HcColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: HcColors.textSecondary),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: profile.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Как к вам обращаться?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Имя', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Сохранить')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(name: name);
    } catch (e) {
      if (context.mounted) showHcSnack(context, ApiException.messageOf(e));
    }
  }
}

class _PushToggle extends ConsumerWidget {
  const _PushToggle({required this.profile});

  final GuestProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushServiceProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.l, vertical: HcSpace.m),
      child: Row(
        children: [
          const IconTile(Icons.notifications_none_rounded, size: 40),
          const SizedBox(width: HcSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Новости и акции', style: HcType.sans(size: 15.5, weight: 500)),
                Text(
                  push.enabled
                      ? 'Уведомления о новинках и акциях — по вашему согласию'
                      : 'Уведомления не настроены в этой сборке',
                  style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: profile.pushNewsEnabled && push.enabled,
            onChanged: push.enabled
                ? (v) async {
                    selectionHaptic();
                    // Включение — это согласие на рекламу (38-ФЗ ст. 18): спрашиваем явно
                    if (v && !await _askMarketingConsent(context)) return;
                    try {
                      await ref.read(authControllerProvider.notifier).updateProfile(pushNewsEnabled: v);
                    } catch (e) {
                      if (context.mounted) showHcSnack(context, ApiException.messageOf(e));
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

/// Отдельное согласие на рекламу перед включением «Новостей и акций».
Future<bool> _askMarketingConsent(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Новости и акции'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Разрешите присылать уведомления о новинках меню, событиях и акциях кофейни. '
            'Это согласие на получение рекламы — его можно отозвать в любой момент этим же переключателем.',
          ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => context.push('/legal/marketing'),
            child: const Text('Текст согласия'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Не сейчас')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Даю согласие')),
      ],
    ),
  );
  return ok == true;
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const Divider(indent: HcSpace.l + 40 + HcSpace.m, endIndent: HcSpace.l),
              c,
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap, this.subtitle, this.color = HcColors.text});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.985,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HcSpace.l, vertical: HcSpace.m),
          child: Row(
            children: [
              IconTile(icon, size: 40, color: color == HcColors.text ? HcColors.accentDark : color),
              const SizedBox(width: HcSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HcType.sans(size: 15.5, weight: 500, color: color)),
                    if (subtitle != null)
                      Text(subtitle!, style: HcType.sans(size: 12.5, color: HcColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HcColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
