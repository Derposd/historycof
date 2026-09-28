import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/guest_profile.dart';
import '../../core/push/push_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../contacts/contacts_providers.dart';
import '../contacts/venue.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).value;
    final venue = ref.watch(venueProvider).value ?? Venue.fallback;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 110),
        children: [
          const ScreenTitle('Профиль', overline: 'History Coffee'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: profile == null ? _SignInCard() : _ProfileCard(profile: profile),
          ),
          const SizedBox(height: 22),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: CapsLabel('Обратная связь')),
          const SizedBox(height: 8),
          _Group(children: [
            _Row(icon: Icons.edit_note_rounded, title: 'Написать нам', subtitle: 'Жалоба, предложение, благодарность', onTap: () => context.push('/feedback/new')),
            if (profile != null)
              _Row(icon: Icons.mark_email_read_outlined, title: 'Мои обращения', onTap: () => context.push('/feedback/mine')),
          ]),
          if (profile != null) ...[
            const SizedBox(height: 22),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: CapsLabel('Уведомления')),
            const SizedBox(height: 8),
            _Group(children: [_PushToggle(profile: profile)]),
          ],
          const SizedBox(height: 22),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: CapsLabel('О приложении')),
          const SizedBox(height: 8),
          _Group(children: [
            _Row(icon: Icons.shield_outlined, title: 'Политика конфиденциальности', onTap: () => context.push('/privacy')),
            if (profile != null) ...[
              _Row(icon: Icons.logout_rounded, title: 'Выйти', onTap: () => _confirmLogout(context, ref)),
              _Row(
                icon: Icons.delete_outline_rounded,
                title: 'Удалить аккаунт',
                color: HcColors.terracotta,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ]),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${venue.legalName}\n${venue.address}',
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
  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Мы помним ваши имена', style: HcType.serif(size: 26)),
          const SizedBox(height: 6),
          Text(
            'И любимые сиропы, и все «мне как обычно». Войдите, чтобы копить бонусы и получать ответы на обращения.',
            style: HcType.sans(color: HcColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => context.push('/login'), child: const Text('Войти по номеру'))),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final GuestProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Glass(
      padding: const EdgeInsets.all(20),
      onTap: () => _editName(context, ref),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: HcColors.accent.withValues(alpha: 0.15)),
            child: Text(
              (profile.name?.isNotEmpty ?? false) ? profile.name!.characters.first.toUpperCase() : 'H',
              style: HcType.serif(size: 28, weight: 600, color: HcColors.accentDark),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name?.isNotEmpty == true ? profile.name! : 'Гость History', style: HcType.serif(size: 24, weight: 600)),
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
    return SwitchListTile(
      value: profile.pushNewsEnabled && push.enabled,
      onChanged: push.enabled
          ? (v) async {
              try {
                await ref.read(authControllerProvider.notifier).updateProfile(pushNewsEnabled: v);
                await push.setNewsSubscription(v);
              } catch (e) {
                if (context.mounted) showHcSnack(context, ApiException.messageOf(e));
              }
            }
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      title: Text('Новости кофейни', style: HcType.sans(size: 15.5, weight: 500)),
      subtitle: Text(
        push.enabled ? 'Новые десерты, события, акции' : 'Push-уведомления не настроены в этой сборке',
        style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const Hairline(indent: 18),
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: Icon(icon, color: color == HcColors.text ? HcColors.accentDark : color),
      title: Text(title, style: HcType.sans(size: 15.5, weight: 500, color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: HcType.sans(size: 12.5, color: HcColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: HcColors.textSecondary),
    );
  }
}
