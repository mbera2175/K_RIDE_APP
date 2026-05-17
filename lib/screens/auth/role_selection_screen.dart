import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import 'otp_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40), // Reduced from 60

                // ── Logo ────────────────────────────────
                Container(
                  width: 70, height: 70, // Reduced from 80
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: Colors.white, size: 38),
                ),
                const SizedBox(height: 16),
                Text("KRide",
                  style: GoogleFonts.sora(
                    fontSize: 28, fontWeight: FontWeight.w700, // Reduced from 32
                    color: AppColors.textPrimary,
                  )),
                const SizedBox(height: 4),
                Text('India\'s Ride & Delivery App 🇮🇳',
                  style: GoogleFonts.sora(
                    fontSize: 13, color: AppColors.textSecondary,
                  )),

                const SizedBox(height: 40), // Reduced from 60

                // ── Heading ──────────────────────────────
                Text('How do you want to join?',
                  style: GoogleFonts.sora(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
                const SizedBox(height: 6),
                Text('Choose your role to get started',
                  style: GoogleFonts.sora(
                    fontSize: 13, color: AppColors.textSecondary,
                  )),

                const SizedBox(height: 30), // Reduced from 40

                // ── Rider Card ───────────────────────────
                _RoleCard(
                  icon: Icons.person_rounded,
                  iconBg: AppColors.primary,
                  title: 'I\'m a Rider',
                  subtitle: 'Book rides & deliveries anywhere in India',
                  badge: '₹50 free on signup!',
                  badgeColor: AppColors.success,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const OtpScreen(role: 'rider'),
                  )),
                ),

                const SizedBox(height: 12),

                // ── Driver Card ──────────────────────────
                _RoleCard(
                  icon: Icons.drive_eta_rounded,
                  iconBg: AppColors.driverColor,
                  title: 'I\'m a Driver / Captain',
                  subtitle: 'Earn money by driving or delivering packages',
                  badge: 'Earn ₹500–₹2000/day',
                  badgeColor: AppColors.driverColor,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const OtpScreen(role: 'driver'),
                  )),
                ),

                const SizedBox(height: 40),

                // ── Footer ───────────────────────────────
                Text('By continuing you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 10, color: AppColors.textSecondary,
                  )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon, required this.iconBg, required this.title,
    required this.subtitle, required this.badge, required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(color: AppColors.shadow,
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg, size: 30),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.sora(
                      fontSize: 17, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                    style: GoogleFonts.sora(
                      fontSize: 12, color: AppColors.textSecondary,
                      height: 1.5,
                    )),
                  const SizedBox(height: 8),
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge,
                      style: GoogleFonts.sora(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: badgeColor,
                      )),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
