import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
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
      await ref.read(feedbackRepositoryProvider).submit(
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
          duration: const Duration(milliseconds: 300),
          child: _sent ? _SentView(type: _type, signedIn: signedIn) : _buildForm(signedIn),
        ),
      ),
    );
  }

  Widget _buildForm(bool signedIn) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Расскажите, что понравилось или что нам стоит исправить. Сообщение сразу получит управляющий кофейни.',
              style: HcType.sans(color: HcColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          const CapsLabel('Тип обращения'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in FeedbackType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: t == FeedbackType.complaint ? HcColors.terracotta : HcColors.accent,
                  labelStyle: HcType.sans(size: 14, weight: 500, color: _type == t ? Colors.white : HcColors.text),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const CapsLabel('Сообщение'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _message,
            minLines: 5,
            maxLines: 10,
            maxLength: 3000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: switch (_type) {
              FeedbackType.complaint => 'Что пошло не так? Когда это было?',
              FeedbackType.suggestion => 'Что бы вы хотели видеть в History?',
              FeedbackType.thanks => 'Кого или что хочется поблагодарить?',
            }),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Напишите хотя бы пару слов' : null,
          ),
          const SizedBox(height: 14),
          const CapsLabel('Фото (необязательно)'),
          const SizedBox(height: 10),
          _PhotoPicker(
            photo: _photo,
            onCamera: () => _pickPhoto(ImageSource.camera),
            onGallery: () => _pickPhoto(ImageSource.gallery),
            onRemove: () => setState(() => _photo = null),
          ),
          const SizedBox(height: 22),
          CapsLabel(signedIn ? 'Другой номер для связи (необязательно)' : 'Телефон для связи (необязательно)'),
          const SizedBox(height: 10),
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
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Мы увидим номер из вашего профиля и сможем ответить в приложении',
                style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    if (photo != null) {
      return Stack(
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
              child: IconButton(tooltip: 'Убрать фото', icon: const Icon(Icons.close_rounded, size: 18), onPressed: onRemove),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Камера'),
          ),
        ),
        const SizedBox(width: 10),
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
  const _SentView({required this.type, required this.signedIn});

  final FeedbackType type;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Glass(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuoteMark(size: 72),
              Text(
                type == FeedbackType.thanks ? 'Спасибо, это очень приятно!' : 'Спасибо, что рассказали',
                textAlign: TextAlign.center,
                style: HcType.serif(size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                signedIn
                    ? 'Мы прочитаем обращение и ответим. Статус можно посмотреть в разделе «Мои обращения».'
                    : 'Мы прочитаем обращение и, если вы оставили телефон, свяжемся с вами.',
                textAlign: TextAlign.center,
                style: HcType.sans(color: HcColors.textSecondary),
              ),
              const SizedBox(height: 22),
              if (signedIn)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.pushReplacement('/feedback/mine'),
                    child: const Text('Мои обращения'),
                  ),
                ),
              const SizedBox(height: 8),
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
