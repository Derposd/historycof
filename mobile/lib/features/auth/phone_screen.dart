import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/logo.dart';

/// Шаг 1 входа: номер телефона.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => phoneDigits(_phone.text).length == 10;

  Future<void> _submit() async {
    if (!_valid || _loading) return;
    final phone = '+7${phoneDigits(_phone.text)}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      await context.push(
        '/login/code',
        extra: CodeScreenArgs(phone: phone, isNewUser: result.isNewUser, resendInSec: result.resendInSec),
      );
    } on ApiException catch (e) {
      // Код уже отправлен недавно — всё равно пускаем на экран ввода.
      if (e.code == 'otp_cooldown' && mounted) {
        await context.push(
          '/login/code',
          extra: CodeScreenArgs(phone: phone, resendInSec: (e.data['resendInSec'] as num?)?.toInt() ?? 60),
        );
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const CloseButton()),
      extendBodyBehindAppBar: true,
      body: HcBackground(
        intensity: 0.8,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.xxl, HcSpace.gutter, HcSpace.xl),
            children: [
              const HcLogo(size: 44, animate: true),
              const SizedBox(height: HcSpace.xxl),
              Text('Вход', style: HcType.serif(size: 38, weight: 600)),
              const SizedBox(height: HcSpace.s),
              Text(
                'Номер телефона станет вашей бонусной картой. Пришлём SMS с кодом.',
                style: HcType.sans(color: HcColors.textSecondary),
              ),
              const SizedBox(height: HcSpace.xl),
              const SectionLabel('Телефон'),
              const SizedBox(height: HcSpace.s),
              TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [RuPhoneInputFormatter()],
                style: HcType.sans(size: 20, weight: 500, letterSpacing: 0.5),
                decoration: InputDecoration(hintText: '+7 (___) ___-__-__', errorText: _error),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: HcSpace.xl),
              FilledButton(
                onPressed: _valid && !_loading ? _submit : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Получить код'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CodeScreenArgs {
  const CodeScreenArgs({required this.phone, this.isNewUser, this.resendInSec = 60});

  final String phone;

  /// null — неизвестно (код уже был отправлен ранее); тогда согласие показываем
  /// и отправляем его вместе с кодом — для существующего гостя это безвредно.
  final bool? isNewUser;
  final int resendInSec;
}
