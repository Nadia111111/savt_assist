import 'package:flutter/material.dart';

class ShuCard extends StatelessWidget {
  final String type;
  final String objectNumber;
  final int warrantyDaysRemaining;
  final String warrantyStatus; // 'active', 'expiring', 'expired'
  final int unreadMessages;
  final VoidCallback onTap;

  const ShuCard({
    super.key,
    required this.type,
    required this.objectNumber,
    required this.warrantyDaysRemaining,
    required this.warrantyStatus,
    required this.unreadMessages,
    required this.onTap,
  });

  Color get _warrantyColor {
    switch (warrantyStatus) {
      case 'active':
        return const Color(0xFF10B981);
      case 'expiring':
        return const Color(0xFFF59E0B);
      case 'expired':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF10B981);
    }
  }

  String get _warrantyText {
    if (warrantyDaysRemaining > 0) {
      return 'Осталось $warrantyDaysRemaining ${_getDaysWord(warrantyDaysRemaining)}';
    } else {
      return 'Истекла ${warrantyDaysRemaining.abs()} ${_getDaysWord(warrantyDaysRemaining.abs())} назад';
    }
  }

  String _getDaysWord(int days) {
    final lastDigit = days % 10;
    final lastTwo = days % 100;
    if (lastTwo >= 11 && lastTwo <= 19) return 'дней';
    if (lastDigit == 1) return 'день';
    if (lastDigit >= 2 && lastDigit <= 4) return 'дня';
    return 'дней';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        objectNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (unreadMessages > 0)
                      Stack(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF054582),
                            size: 20,
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF991B1B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _warrantyColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _warrantyText,
                  style: TextStyle(
                    color: _warrantyColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
