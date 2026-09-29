import 'dart:async';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/motion.dart';
import 'loyalty.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);

    if (!signedIn) {
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: HcSpace.navInset(context)),
          children: [
            const ScreenTitle('Бонусы'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: FadeSlideIn(child: _GuestInvite(onLogin: () => context.push('/login'))),
            ),
          ],
        ),
      );
    }

    final summary = ref.watch(loyaltySummaryProvider);
    final history = ref.watch(loyaltyTransactionsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: HcColors.accent,
        onRefresh: () async {
          ref.invalidate(loyaltyTransactionsProvider);
          await ref.read(loyaltySummaryProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.only(bottom: HcSpace.navInset(context)),
          children: [
            const ScreenTitle('Бонусы'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.slow),
                switchInCurve: Motion.emphasized,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
                ),
                child: switch (summary) {
                  AsyncData(:final value?) => LoyaltyCardView(key: const ValueKey('card'), summary: value),
                  AsyncError(:final error) => Glass(
                    key: const ValueKey('error'),
                    padding: const EdgeInsets.symmetric(vertical: HcSpace.m),
                    child: ErrorState(error: error, onRetry: () => ref.invalidate(loyaltySummaryProvider)),
                  ),
                  _ => const _CardSkeleton(key: ValueKey('skeleton')),
                },
              ),
            ),
            const SizedBox(height: HcSpace.l),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: HcColors.textSecondary),
                  const SizedBox(width: HcSpace.s),
                  Expanded(
                    child: Text(
                      'Покажите код бариста перед оплатой — бонусы начислятся или спишутся на кассе.',
                      style: HcType.sans(size: 13, color: HcColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HcSpace.section),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: SectionLabel('История операций'),
            ),
            const SizedBox(height: HcSpace.s),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HcSpace.gutter),
              child: SoftCard(
                padding: EdgeInsets.zero,
                child: AnimatedSize(
                  duration: Motion.of(context, Motion.medium),
                  curve: Motion.curve,
                  alignment: Alignment.topCenter,
                  child: switch (history) {
                    AsyncData(:final value) when value.isEmpty => const _HistoryNote('Операций пока нет'),
                    AsyncData(:final value) => Column(
                      children: [
                        for (final (i, t) in value.indexed) ...[
                          if (i > 0) const Hairline(indent: HcSpace.l),
                          FadeSlideIn(index: i, offset: 8, child: _TransactionTile(t)),
                        ],
                      ],
                    ),
                    AsyncError() => const _HistoryNote('Не удалось загрузить историю'),
                    _ => const Padding(
                      padding: EdgeInsets.all(HcSpace.l),
                      child: Column(
                        children: [
                          SkeletonBox(height: 20),
                          SizedBox(height: HcSpace.m),
                          SkeletonBox(height: 20),
                        ],
                      ),
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryNote extends StatelessWidget {
  const _HistoryNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(HcSpace.card),
    child: Text(text, style: HcType.sans(color: HcColors.textSecondary)),
  );
}

/// Карта лояльности: стекло поверх размытого тёплого градиента.
class LoyaltyCardView extends StatelessWidget {
  const LoyaltyCardView({super.key, required this.summary});

  final LoyaltySummary summary;

  static const _radius = HcRadii.card + 4;

  @override
  Widget build(BuildContext context) {
    // Обрезаем по скруглению, чтобы цветные пятна не выходили за углы карты.
    return _TiltSheen(
      builder: (light) => ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC3CBAA), Color(0xFFEBDDB4), Color(0xFFE2BFA9)],
                  ),
                ),
              ),
            ),
            Positioned(right: -30, top: -40, child: _blob(170, HcColors.gold)),
            Positioned(left: -50, bottom: -40, child: _blob(190, HcColors.accentDark.withValues(alpha: 0.5))),
            // Свет под матовым стеклом: блик и отсвет пальца размываются стеклом
            // и не ложатся поверх QR-кода (иначе касса могла бы не считать код).
            Positioned.fill(child: light),
            Glass(
              radius: _radius,
              blur: 26,
              fill: const Color(0x8CFFFFFF),
              padding: const EdgeInsets.all(HcSpace.card),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const HcLogo(size: 30, showSubtitle: false),
                      const Spacer(),
                      if (summary.guestName != null && summary.guestName!.isNotEmpty)
                        SectionLabel(summary.guestName!, color: HcColors.text),
                    ],
                  ),
                  const SizedBox(height: HcSpace.xl),
                  const SectionLabel('Баланс', color: HcColors.text),
                  Semantics(
                    label: 'Баланс ${summary.balance} ${pluralRu(summary.balance, 'бонус', 'бонуса', 'бонусов')}',
                    excludeSemantics: true,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: summary.balance.toDouble()),
                      duration: Motion.of(context, const Duration(milliseconds: 900)),
                      curve: Motion.curve,
                      builder: (context, v, _) => Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatNumber(v.round()),
                            style: HcType.serif(size: 56, weight: 600, height: 1.05, tabular: true),
                          ),
                          const SizedBox(width: HcSpace.s),
                          Text(
                            pluralRu(summary.balance, 'бонус', 'бонуса', 'бонусов'),
                            style: HcType.sans(size: 16, weight: 500, color: HcColors.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: HcSpace.l),
                  Pressable(
                    onTap: () => _showFullscreenCode(context, summary.card),
                    child: Container(
                      padding: const EdgeInsets.all(HcSpace.l),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(HcRadii.small),
                      ),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'loyalty-qr',
                            child: Semantics(
                              label: 'QR-код карты для сканирования на кассе',
                              child: BarcodeWidget(
                                barcode: Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium),
                                data: summary.card.barcode,
                                width: 112,
                                height: 112,
                                color: HcColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: HcSpace.l),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionLabel('Номер карты', size: 12),
                                const SizedBox(height: HcSpace.xs),
                                Text(
                                  summary.card.cardNumber,
                                  style: HcType.sans(size: 17, weight: 600, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: HcSpace.m),
                                Row(
                                  children: [
                                    const Icon(Icons.open_in_full_rounded, size: 14, color: HcColors.accentDark),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Показать крупно',
                                      style: HcType.sans(size: 13, color: HcColors.accentDark, weight: 600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _blob(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

/// «Живая» карта: наклоняется в 3D за пальцем (с бликом под пальцем) и мягко
/// возвращается; время от времени по ней проходит световая полоса, как по
/// пластиковой карте. Касания не перехватываются — прокрутка и кнопки работают.
/// Между проходами блика кадры не рисуются, чтобы не тратить батарею.
class _TiltSheen extends StatefulWidget {
  const _TiltSheen({required this.builder});

  /// Строит карту; [light] — слой света, который карта кладёт под своё стекло.
  final Widget Function(Widget light) builder;

  @override
  State<_TiltSheen> createState() => _TiltSheenState();
}

class _TiltSheenState extends State<_TiltSheen> with TickerProviderStateMixin {
  static const _maxTilt = 0.11; // ≈6°

  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  Timer? _next;

  Offset _tilt = Offset.zero; // x — наклон по горизонтали, y — по вертикали, −1…1
  Offset _from = Offset.zero;
  Offset? _touch; // точка касания в долях карты — для блика
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _release.addListener(() {
      setState(() => _tilt = Offset.lerp(_from, Offset.zero, Curves.elasticOut.transform(_release.value))!);
    });
    _sheen.addStatusListener((s) {
      if (s == AnimationStatus.completed) _schedule(const Duration(seconds: 7));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = Motion.reduced(context);
    if (!_reduced && _next == null && !_sheen.isAnimating) _schedule(const Duration(milliseconds: 700));
  }

  void _schedule(Duration d) {
    _next?.cancel();
    _next = Timer(d, () {
      if (mounted && !_reduced) _sheen.forward(from: 0);
    });
  }

  void _onMove(PointerEvent e, Size size) {
    if (_reduced || size.isEmpty) return;
    final p = Offset(e.localPosition.dx / size.width, e.localPosition.dy / size.height);
    _release.stop();
    setState(() {
      _touch = p;
      _tilt = Offset((p.dx * 2 - 1).clamp(-1, 1), (p.dy * 2 - 1).clamp(-1, 1));
    });
  }

  void _onUp() {
    if (_reduced) return;
    _from = _tilt;
    setState(() => _touch = null);
    _release.forward(from: 0);
  }

  @override
  void dispose() {
    _next?.cancel();
    _sheen.dispose();
    _release.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _onMove(e, context.size ?? Size.zero),
      onPointerMove: (e) => _onMove(e, context.size ?? Size.zero),
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _onUp(),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateX(-_tilt.dy * _maxTilt)
          ..rotateY(_tilt.dx * _maxTilt),
        child: widget.builder(
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Световая полоса по диагонали.
                AnimatedBuilder(
                  animation: _sheen,
                  builder: (context, _) {
                    if (!_sheen.isAnimating) return const SizedBox.shrink();
                    final t = Curves.easeInOutCubic.transform(_sheen.value);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1 + 3.4 * t - 1.2, -1),
                          end: Alignment(-1 + 3.4 * t - 0.2, 1),
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.28, 0.5, 0.72],
                        ),
                      ),
                    );
                  },
                ),
                // Отсвет под пальцем.
                if (_touch != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(_touch!.dx * 2 - 1, _touch!.dy * 2 - 1),
                        radius: 0.75,
                        colors: [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showFullscreenCode(BuildContext context, LoyaltyCard card) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: HcColors.text.withValues(alpha: 0.45),
    transitionDuration: Motion.of(context, Motion.medium),
    transitionBuilder: (context, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Motion.emphasized, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: c,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(c), child: child),
      );
    },
    pageBuilder: (context, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(HcSpace.xl),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HcRadii.card + 4),
          child: Padding(
            padding: const EdgeInsets.all(HcSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'loyalty-qr',
                  child: BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: card.barcode,
                    width: 240,
                    height: 240,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: HcSpace.xl),
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: card.barcode,
                  height: 64,
                  drawText: false,
                  color: Colors.black,
                ),
                const SizedBox(height: HcSpace.m),
                Text(card.cardNumber, style: HcType.sans(size: 20, weight: 600, letterSpacing: 1.6)),
                const SizedBox(height: HcSpace.l),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.t);

  final LoyaltyTransaction t;

  @override
  Widget build(BuildContext context) {
    final positive = t.amount > 0;
    final color = positive ? HcColors.accentDark : HcColors.terracotta;
    final sign = positive ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HcSpace.l, vertical: HcSpace.m),
      child: Row(
        children: [
          IconTile(positive ? Icons.add_rounded : Icons.remove_rounded, size: 40, color: color),
          const SizedBox(width: HcSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: HcType.sans(size: 15, weight: 500)),
                const SizedBox(height: 2),
                Text(
                  [formatDateTimeShort(t.date), if (t.orderNumber != null) 'заказ №${t.orderNumber}'].join(' · '),
                  style: HcType.sans(size: 12.5, color: HcColors.textSecondary),
                ),
              ],
            ),
          ),
          Text('$sign${formatNumber(t.amount.abs())}', style: HcType.serif(size: 22, weight: 600, color: color)),
        ],
      ),
    );
  }
}

class _GuestInvite extends StatelessWidget {
  const _GuestInvite({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.all(HcSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(Icons.qr_code_2_rounded, size: 56),
          const SizedBox(height: HcSpace.l),
          Text('Карта гостя в телефоне', style: HcType.serif(size: 28, weight: 600)),
          const SizedBox(height: HcSpace.s),
          Text(
            'Войдите по номеру телефона — карта появится сразу. Покажите её на кассе, чтобы копить бонусы '
            'и оплачивать ими часть заказа.',
            style: HcType.sans(color: HcColors.textSecondary),
          ),
          const SizedBox(height: HcSpace.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onLogin, child: const Text('Войти по номеру')),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Glass(
    padding: EdgeInsets.all(HcSpace.card),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 30, width: 120),
        SizedBox(height: HcSpace.xl),
        SkeletonBox(height: 52, width: 170),
        SizedBox(height: HcSpace.l),
        SkeletonBox(height: 144),
      ],
    ),
  );
}
