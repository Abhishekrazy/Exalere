import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// A 10-foot Leanback TV dialog displaying a high-contrast QR code
/// for donating to Exalere development via mobile phone.
class TvDonateDialog extends StatelessWidget {
  const TvDonateDialog({super.key});

  static Future<void> show(BuildContext context) {
    final tokens = context.tokens;
    return showDialog(
      context: context,
      barrierColor: tokens.shadowColor.withValues(alpha: 0.85),
      builder: (ctx) => const TvDonateDialog(),
    );
  }

  static const String donateUrl = 'https://razorpay.me/@abhishekrazy';
  static const String qrImageUrl =
      'https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=8&data=https%3A%2F%2Frazorpay.me%2F%40abhishekrazy';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: tokens.surfaceElevated,
      shape: tokens.getShapeBorder(
        radius: tokens.cardRadius * 1.35,
        side: BorderSide(
          color: tokens.primaryAccent.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.primaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: tokens.primaryAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Support Exalere',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Scan this QR code with your phone camera to donate directly from your mobile device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: tokens.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // QR Code Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceCard,
                  radius: tokens.cardRadius,
                  side: BorderSide(color: tokens.borderSubtle, width: 1.0),
                ),
                child: tokens.clipShape(
                  radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                  child: Image.asset(
                    'assets/images/donate_qr.png',
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        CachedNetworkImage(
                          imageUrl: qrImageUrl,
                          width: 170,
                          height: 170,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => SizedBox(
                            width: 170,
                            height: 170,
                            child: Center(
                              child: Icon(
                                Icons.qr_code_rounded,
                                size: 48,
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Razorpay Direct Web Link Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceCard.withValues(alpha: 0.6),
                  radius: tokens.cornerStyle == CornerStyle.sharp ? 0.0 : 20.0,
                  side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'razorpay.me/@abhishekrazy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Payment options subtitle
              Text(
                'UPI • Google Pay • PhonePe • Cards • NetBanking',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 20),

              // Autofocused Close Button for TV Remote
              TvFocusable(
                autofocus: true,
                onTap: () => Navigator.of(context).pop(),
                shape: tokens.shapeSm,
                borderRadius: tokens.borderRadiusSm,
                scaleFactor: 1.04,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.primaryAccent,
                    radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
