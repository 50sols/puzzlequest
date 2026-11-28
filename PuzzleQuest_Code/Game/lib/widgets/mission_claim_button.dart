import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Always reserves a visible action for each mission.
/// The backend remains the only authority for reward eligibility and claiming.
class PQMissionClaimButton extends StatelessWidget {
  const PQMissionClaimButton({
    super.key,
    required this.eligible,
    required this.claimed,
    required this.arabic,
    this.onClaim,
  });

  final bool eligible, claimed, arabic;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final canClaim = eligible && !claimed && onClaim != null;
    final title = claimed
        ? (arabic ? 'تم تحصيل المكافأة' : 'Reward collected')
        : canClaim
            ? (arabic ? 'تحصيل المكافأة' : 'Collect reward')
            : (arabic ? 'أكمل المهمة للتحصيل' : 'Complete to collect');
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canClaim ? onClaim : null,
        icon: Icon(
          claimed ? Icons.check_circle_rounded
              : canClaim ? Icons.redeem_rounded : Icons.lock_outline_rounded,
          size: 20,
        ),
        label: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: PQColors.actionGreen,
          foregroundColor: PQColors.background,
          disabledBackgroundColor: PQColors.surface,
          disabledForegroundColor: PQColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: canClaim ? PQColors.gold :
                  claimed ? PQColors.success.withValues(alpha: .55)
                      : PQColors.muted.withValues(alpha: .28),
              width: canClaim ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
