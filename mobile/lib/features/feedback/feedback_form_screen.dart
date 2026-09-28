import 'dart:io';

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
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: Motion.of(context, Motion.slow),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: IconTile(
                  type == FeedbackType.thanks ? Icons.favorite_border_rounded : Icons.check_rounded,
                  size: 64,
                ),
              ),
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
