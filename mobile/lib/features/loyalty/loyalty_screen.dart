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
import '../../core/widgets/wordmark.dart';
import 'loyalty.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 110;

    if (!signedIn) {
      return SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomInset),
          children: [
            const ScreenTitle('Бонусы', overline: 'Карта гостя'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _GuestInvite(onLogin: () => context.push('/login')),
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
          padding: EdgeInsets.only(bottom: bottomInset),
          children: [
            const ScreenTitle('Бонусы', overline: 'Карта гостя'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: switch (summary) {
                AsyncData(:final value?) => LoyaltyCardView(summary: value),
                AsyncError(:final error) => Glass(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ErrorState(error: error, onRetry: () => ref.invalidate(loyaltySummaryProvider)),
                  ),
                _ => const _CardSkeleton(),
              },
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Покажите код бариста перед оплатой — бонусы начислятся или спишутся на кассе',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: HcColors.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 28),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: CapsLabel('История')),
            const SizedBox(height: 8),
            ...switch (history) {
              AsyncData(:final value) when value.isEmpty => [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text('Операций пока нет', style: HcType.sans(color: HcColors.textSecondary)),
                  ),
                ],
              AsyncData(:final value) => [for (final t in value) _TransactionTile(t)],
              AsyncError() => [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text('Не удалось загрузить историю', style: HcType.sans(color: HcColors.textSecondary)),
                  ),
                ],
              _ => [
                  for (var i = 0; i < 3; i++)
                    const Padding(padding: EdgeInsets.fromLTRB(22, 12, 22, 12), child: SkeletonBox(height: 20)),
                ],
            },
          ],
        ),
      ),
    );
  }
}

/// Карта лояльности: стекло поверх размытого тёплого градиента.
class LoyaltyCardView extends StatelessWidget {
  const LoyaltyCardView({super.key, required this.summary});

  final LoyaltySummary summary;

  @override
  Widget build(BuildContext context) {
    // Обрезаем по скруглению, чтобы цветные пятна не выходили за углы карты.
    return ClipRRect(
      borderRadius: BorderRadius.circular(HcRadii.card + 4),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    return Stack(
      children: [
        // Цветная подложка, которую размывает стекло карты.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HcRadii.card + 4),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB9C29F), Color(0xFFE9D7A6), Color(0xFFDDB39C)],
              ),
            ),
          ),
        ),
        Positioned(right: -30, top: -40, child: _blob(160, HcColors.gold)),
        Positioned(left: -40, bottom: -30, child: _blob(180, HcColors.accentDark.withValues(alpha: 0.6))),
        Glass(
          radius: HcRadii.card + 4,
          blur: 26,
          fill: const Color(0x8CFFFFFF),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HistoryWordmark(size: 18),
                  const Spacer(),
                  if (summary.guestName != null) CapsLabel(summary.guestName!, color: HcColors.text),
                ],
              ),
              const SizedBox(height: 18),
              Semantics(
                label: 'Баланс ${summary.balance} ${pluralRu(summary.balance, 'бонус', 'бонуса', 'бонусов')}',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatNumber(summary.balance), style: HcType.serif(size: 58, weight: 500, height: 1)),
                    const SizedBox(width: 10),
                    Text(
                      pluralRu(summary.balance, 'бонус', 'бонуса', 'бонусов'),
                      style: HcType.serif(size: 22, weight: 400, italic: true, color: HcColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => _showFullscreenCode(context, summary.card),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(HcRadii.small)),
                  child: Row(
                    children: [
                      Semantics(
                        label: 'QR-код карты для сканирования на кассе',
                        child: BarcodeWidget(
                          barcode: Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium),
                          data: summary.card.barcode,
                          width: 116,
                          height: 116,
                          color: HcColors.text,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CapsLabel('Номер карты', size: 10),
                            const SizedBox(height: 6),
                            Text(summary.card.cardNumber, style: HcType.sans(size: 17, weight: 500, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.open_in_full_rounded, size: 14, color: HcColors.accentDark),
                                const SizedBox(width: 6),
                                Text('Показать крупно', style: HcType.sans(size: 13, color: HcColors.accentDark, weight: 500)),
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

void _showFullscreenCode(BuildContext context, LoyaltyCard card) {
  showDialog<void>(
    context: context,
    barrierColor: HcColors.text.withValues(alpha: 0.4),
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarcodeWidget(barcode: Barcode.qrCode(), data: card.barcode, width: 240, height: 240, color: Colors.black),
            const SizedBox(height: 20),
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: card.barcode,
              height: 64,
              drawText: false,
              color: Colors.black,
            ),
            const SizedBox(height: 12),
            Text(card.cardNumber, style: HcType.sans(size: 20, weight: 500, letterSpacing: 2)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Готово')),
          ],
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
          child: Row(
            children: [
              RoundOutlineIcon(positive ? Icons.add_rounded : Icons.remove_rounded, size: 38, color: color),
              const SizedBox(width: 14),
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
        ),
        const Hairline(indent: 22),
      ],
    );
  }
}

class _GuestInvite extends StatelessWidget {
  const _GuestInvite({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Glass(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          const RoundOutlineIcon(Icons.qr_code_2_rounded, size: 64),
          const SizedBox(height: 18),
          Text('Ваша карта гостя', style: HcType.serif(size: 28)),
          const SizedBox(height: 10),
          Text(
            'Войдите по номеру телефона — и бонусная карта всегда будет в телефоне. '
            'Покажите её бариста, чтобы копить и тратить бонусы.',
            textAlign: TextAlign.center,
            style: HcType.sans(color: HcColors.textSecondary),
          ),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: onLogin, child: const Text('Войти по номеру'))),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => const Glass(
        padding: EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 16, width: 110),
            SizedBox(height: 22),
            SkeletonBox(height: 48, width: 160),
            SizedBox(height: 22),
            SkeletonBox(height: 148),
          ],
        ),
      );
}
