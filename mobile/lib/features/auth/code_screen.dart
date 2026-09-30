import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/demo_interceptor.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/background.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/motion.dart';
import 'phone_screen.dart';

const _codeLength = 4;

/// Шаг 2 входа: код из SMS. Новому гостю — согласие на обработку ПДн (152-ФЗ) и имя.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key, required this.args});

  final CodeScreenArgs args;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> with SingleTickerProviderStateMixin {
  /// Короткое «покачивание» поля при неверном коде.
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  final _code = TextEditingController();
  final _name = TextEditingController();
  late int _resendIn = widget.args.resendInSec;
  Timer? _timer;

  /// Согласие на обработку ПДн — отдельный документ, обязательное (152-ФЗ, ред. с 01.09.2025).
  bool _consent = false;

  /// Согласие на рекламу (новости и акции) — отдельное и необязательное (38-ФЗ ст. 18).
  bool _marketing = false;
  bool _loading = false;
  String? _error;

  bool get _needsConsent => widget.args.isNewUser != false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _canSubmit => _code.text.length == _codeLength && (!_needsConsent || _consent) && !_loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(
            phone: widget.args.phone,
            code: _code.text,
            acceptPersonalData: _needsConsent && _consent,
            acceptMarketing: _needsConsent && _marketing,
            name: widget.args.isNewUser == true ? _name.text : null,
          );
      if (!mounted) return;
      // Закрываем оба экрана входа (код и телефон) и возвращаемся туда, откуда пришли.
      final router = GoRouter.of(context);
      router.pop();
      if (router.canPop()) router.pop();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        if (e.code != 'consent_required') _code.clear();
      });
      if (!Motion.reduced(context)) unawaited(_shake.forward(from: 0));
      unawaited(HapticFeedback.mediumImpact());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final r = await ref.read(authControllerProvider.notifier).requestOtp(widget.args.phone);
      setState(() {
        _resendIn = r.resendInSec;
        _error = null;
      });
      _startTimer();
      if (mounted) showHcSnack(context, 'Код отправлен повторно');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      extendBodyBehindAppBar: true,
      body: HcBackground(
        intensity: 0.8,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(HcSpace.gutter, HcSpace.xxl, HcSpace.gutter, HcSpace.xl),
            children: [
              Text('Код из SMS', style: HcType.serif(size: 38, weight: 600)),
              const SizedBox(height: HcSpace.s),
              Text(
                AppConfig.demo
                    ? 'Демо-версия: SMS не отправляется, введите ${DemoInterceptor.demoCode}'
                    : 'Отправили на ${formatPhone(widget.args.phone)}',
                style: HcType.sans(color: HcColors.textSecondary),
              ),
              const SizedBox(height: HcSpace.xl),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  // затухающая синусоида: 3 качания, амплитуда 10px
                  final dx = t == 0 ? 0.0 : 10 * (1 - t) * math.sin(t * math.pi * 6);
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: _codeLength,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: HcType.serif(size: 40, weight: 500, letterSpacing: 18),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • •',
                    errorText: _error,
                    errorMaxLines: 3,
                  ),
                  onChanged: (v) {
                    setState(() => _error = null);
                    if (v.length == _codeLength) _submit();
                  },
                ),
              ),
              const SizedBox(height: HcSpace.s),
              Center(
                child: _resendIn > 0
                    ? Text(
                        'Отправить снова через $_resendIn с',
                        style: HcType.sans(size: 13.5, color: HcColors.textSecondary),
                      )
                    : TextButton(onPressed: _resend, child: const Text('Отправить код снова')),
              ),
              if (widget.args.isNewUser == true) ...[
                const SizedBox(height: HcSpace.l),
                const SectionLabel('Как к вам обращаться, если хотите'),
                const SizedBox(height: HcSpace.s),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  maxLength: 80,
                  decoration: const InputDecoration(hintText: 'Имя', counterText: ''),
                ),
              ],
              if (_needsConsent) ...[
                const SizedBox(height: HcSpace.l),
                _ConsentCheckbox(
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v),
                  lead: 'Даю ',
                  link: 'согласие на обработку персональных данных',
                  route: '/legal/consent',
                  tail: ' (обязательно)',
                ),
                _ConsentCheckbox(
                  value: _marketing,
                  onChanged: (v) => setState(() => _marketing = v),
                  lead: 'Хочу получать новости и акции кофейни — ',
                  link: 'согласие на рекламу',
                  route: '/legal/marketing',
                  tail: ' (по желанию)',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: GestureDetector(
                    onTap: () => context.push('/legal/privacy'),
                    child: Text(
                      'Политика обработки персональных данных',
                      style: HcType.sans(
                        size: 13,
                        color: HcColors.accentDark,
                        height: 1.4,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: HcSpace.xl),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Отдельная галочка согласия: по умолчанию снята, текст документа — по ссылке.
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.lead,
    required this.link,
    required this.route,
    this.tail = '',
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String lead;
  final String link;
  final String route;
  final String tail;

  @override
  Widget build(BuildContext context) {
    final base = HcType.sans(size: 13.5, color: HcColors.textSecondary, height: 1.4);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: base,
                    children: [
                      TextSpan(text: lead),
                      TextSpan(
                        text: link,
                        style: base.copyWith(color: HcColors.accentDark, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () => context.push(route),
                      ),
                      TextSpan(text: tail),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
