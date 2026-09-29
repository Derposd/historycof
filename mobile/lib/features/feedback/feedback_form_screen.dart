import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/motion.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../menu/menu_screen.dart' show SegmentedSwitch;
import 'feedback.dart';

class FeedbackFormScreen extends ConsumerStatefulWidget {
  const FeedbackFormScreen({super.key, this.initialType = FeedbackType.complaint});

  final FeedbackType initialType;

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  late FeedbackType _type = widget.initialType;
  final _message = TextEditingController();
  final _phone = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  XFile? _photo;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
      if (file != null) setState(() => _photo = file);
    } catch (_) {
      if (mounted) showHcSnack(context, 'Нет доступа к ${source == ImageSource.camera ? 'камере' : 'галерее'}');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final digits = phoneDigits(_phone.text);
      await ref
          .read(feedbackRepositoryProvider)
          .submit(
            type: _type,
            message: _message.text,
            contactPhone: digits.length == 10 ? '+7$digits' : null,
            photoPath: _photo?.path,
          );
      ref.invalidate(myFeedbackProvider);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showHcSnack(context, ApiException.messageOf(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isSignedInProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Обратная связь')),
      body: HcBackground(
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.slow),
          transitionBuilder: (child, a) => fadeThroughTransition(child, a),
          child: _sent
              ? _SentView(key: const ValueKey('sent'), type: _type, signedIn: signedIn)
              : KeyedSubtree(key: const ValueKey('form'), child: _buildForm(signedIn)),
        ),
      ),
    );
  }

  Widget _buildForm(bool signedIn) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          HcSpace.gutter,
          HcSpace.s,
          HcSpace.gutter,
          MediaQuery.paddingOf(context).bottom + HcSpace.xl,
        ),
        children: [
          Text(
            'Расскажите, что понравилось или что стоит исправить. Сообщение сразу получит управляющий кофейни.',
            style: HcType.sans(color: HcColors.textSecondary),
          ),
          const SizedBox(height: HcSpace.xl),
          const SectionLabel('Тип обращения'),
          const SizedBox(height: HcSpace.s),
          SegmentedSwitch(
            labels: [for (final t in FeedbackType.values) t.label],
            index: FeedbackType.values.indexOf(_type),
            onChanged: (i) => setState(() => _type = FeedbackType.values[i]),
          ),
          const SizedBox(height: HcSpace.xl),
          const SectionLabel('Сообщение'),
          const SizedBox(height: HcSpace.s),
          TextFormField(
            controller: _message,
            minLines: 5,
            maxLines: 10,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: switch (_type) {
                FeedbackType.complaint => 'Что пошло не так? Когда это было?',
                FeedbackType.suggestion => 'Что бы вы хотели видеть в History?',
                FeedbackType.thanks => 'Кого или что хочется поблагодарить?',
              },
            ),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Напишите хотя бы пару слов' : null,
          ),
          const SizedBox(height: HcSpace.l),
          const SectionLabel('Фото, если нужно'),
          const SizedBox(height: HcSpace.s),
          _PhotoPicker(
            photo: _photo,
            onCamera: () => _pickPhoto(ImageSource.camera),
            onGallery: () => _pickPhoto(ImageSource.gallery),
            onRemove: () => setState(() => _photo = null),
          ),
          const SizedBox(height: HcSpace.xl),
          SectionLabel(signedIn ? 'Другой номер для связи, если нужно' : 'Телефон для связи, если хотите ответ'),
          const SizedBox(height: HcSpace.s),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [RuPhoneInputFormatter()],
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(hintText: '+7 (___) ___-__-__'),
            validator: (v) {
              final d = phoneDigits(v ?? '');
              return d.isEmpty || d.length == 10 ? null : 'Проверьте номер';
            },
          ),
          if (signedIn)
            Padding(
              padding: const EdgeInsets.only(top: HcSpace.s),
              child: Text(
                'Мы увидим номер из вашего профиля и сможем ответить в приложении',
                style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
              ),
            ),
          const SizedBox(height: HcSpace.xxl),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Отправить'),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onCamera, required this.onGallery, required this.onRemove});

  final XFile? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, child: child),
      ),
      child: photo != null ? _preview() : _buttons(),
    );
  }

  Widget _preview() {
    {
      return Stack(
        key: const ValueKey('preview'),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(HcRadii.small),
            child: Image.file(File(photo!.path), height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.85),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Убрать фото',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buttons() {
    return Row(
      key: const ValueKey('buttons'),
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Камера'),
          ),
        ),
        const SizedBox(width: HcSpace.m),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Галерея'),
          ),
        ),
      ],
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({super.key, required this.type, required this.signedIn});

  final FeedbackType type;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HcSpace.gutter),
        child: Glass(
          padding: const EdgeInsets.all(HcSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SuccessMark(heart: type == FeedbackType.thanks),
              const SizedBox(height: HcSpace.l),
              Text(
                type == FeedbackType.thanks ? 'Спасибо, это очень приятно!' : 'Спасибо, что рассказали',
                textAlign: TextAlign.center,
                style: HcType.serif(size: 28, weight: 600),
              ),
              const SizedBox(height: HcSpace.s),
              Text(
                signedIn
                    ? 'Мы прочитаем обращение и ответим. Статус можно посмотреть в разделе «Мои обращения».'
                    : 'Мы прочитаем обращение и, если вы оставили телефон, свяжемся с вами.',
                textAlign: TextAlign.center,
                style: HcType.sans(color: HcColors.textSecondary),
              ),
              const SizedBox(height: HcSpace.xl),
              if (signedIn)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.pushReplacement('/feedback/mine'),
                    child: const Text('Мои обращения'),
                  ),
                ),
              const SizedBox(height: HcSpace.s),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => context.pop(), child: const Text('Готово')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Отметка «отправлено»: кольцо прорисовывается линией, внутри рисуется галочка
/// (или «бьётся» сердце для благодарности), от кольца расходится мягкая волна.
class _SuccessMark extends StatefulWidget {
  const _SuccessMark({required this.heart});

  final bool heart;

  @override
  State<_SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<_SuccessMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 88,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final heart = Curves.elasticOut.transform(((t - 0.35) / 0.65).clamp(0, 1));
          return CustomPaint(
            painter: _SuccessPainter(t, drawCheck: !widget.heart),
            child: widget.heart
                ? Center(
                    child: Transform.scale(
                      scale: heart,
                      child: const Icon(Icons.favorite_rounded, size: 34, color: HcColors.terracotta),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter(this.t, {required this.drawCheck});

  final double t;
  final bool drawCheck;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final ring = Curves.easeInOutCubic.transform((t / 0.45).clamp(0, 1));
    final check = Curves.easeOutCubic.transform(((t - 0.4) / 0.35).clamp(0, 1));
    final wave = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

    // Волна
    if (wave > 0 && wave < 1) {
      canvas.drawCircle(
        c,
        r + 12 * Curves.easeOut.transform(wave),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = HcColors.accent.withValues(alpha: 0.45 * (1 - wave)),
      );
    }
    // Мягкая заливка
    canvas.drawCircle(c, r, Paint()..color = HcColors.accentDark.withValues(alpha: 0.10 * ring));
    // Кольцо
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = HcColors.accentDark,
    );
    if (!drawCheck || check <= 0) return;
    // Галочка: два отрезка, второй начинается, когда закончился первый
    final a = c + Offset(-r * 0.36, r * 0.02);
    final b = c + Offset(-r * 0.08, r * 0.30);
    final e = c + Offset(r * 0.40, -r * 0.26);
    final path = Path()..moveTo(a.dx, a.dy);
    final k1 = (check / 0.4).clamp(0.0, 1.0);
    final p1 = Offset.lerp(a, b, k1)!;
    path.lineTo(p1.dx, p1.dy);
    if (check > 0.4) {
      final p2 = Offset.lerp(b, e, ((check - 0.4) / 0.6).clamp(0.0, 1.0))!;
      path.lineTo(p2.dx, p2.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = HcColors.accentDark,
    );
  }

  @override
  bool shouldRepaint(_SuccessPainter old) => old.t != t || old.drawCheck != drawCheck;
}
