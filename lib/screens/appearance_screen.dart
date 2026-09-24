import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currentMode = settings.themeMode;
    
    // Always calculate local colors for this screen so it matches design strictly
    final isDark = settings.isDarkMode;
    final bgColor = isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7);
    final appBarColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Appearance',
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ThemeOption(
                    mode: ThemeMode.light,
                    currentMode: currentMode,
                    title: 'Light',
                    onTap: () => context.read<SettingsProvider>().setThemeMode(ThemeMode.light),
                    textColor: textColor,
                  ),
                  _ThemeOption(
                    mode: ThemeMode.dark,
                    currentMode: currentMode,
                    title: 'Dark',
                    onTap: () => context.read<SettingsProvider>().setThemeMode(ThemeMode.dark),
                    textColor: textColor,
                  ),
                  _ThemeOption(
                    mode: ThemeMode.system,
                    currentMode: currentMode,
                    title: 'System',
                    onTap: () => context.read<SettingsProvider>().setThemeMode(ThemeMode.system),
                    textColor: textColor,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                "If 'system' is selected, the app will automatically adjust your appearance based on your device's system settings.",
                style: GoogleFonts.inter(
                  color: subtitleColor,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemeMode mode;
  final ThemeMode currentMode;
  final String title;
  final VoidCallback onTap;
  final Color textColor;

  const _ThemeOption({
    required this.mode,
    required this.currentMode,
    required this.title,
    required this.onTap,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == currentMode;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          _buildPhoneMockup(context),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Custom Radio Button
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade600,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneMockup(BuildContext context) {
    bool isDarkMock = mode == ThemeMode.dark;
    bool isSystem = mode == ThemeMode.system;

    final mockBg = isDarkMock ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDarkMock ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5E5);

    return Container(
      width: 76,
      height: 160,
      decoration: BoxDecoration(
        color: mockBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: context.isDarkMode ? Colors.transparent : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            if (isSystem)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DiagonalSplitPainter(
                    colorTopLeft: Colors.white,
                    colorBottomRight: const Color(0xFF2C2C2E),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(color: mockBg),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
              child: Column(
                children: [
                  // App Icon (Rocket)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(Icons.rocket_launch_rounded, color: AppTheme.primary, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _mockRect(isDarkMock, isSystem),
                      _mockRect(isDarkMock, isSystem),
                      _mockRect(isDarkMock, isSystem),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _getMockColor(isDarkMock, isSystem, opacity: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Positioned.fill(
              child: CustomPaint(
                painter: _GlossPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mockRect(bool isDarkMock, bool isSystem) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: _getMockColor(isDarkMock, isSystem, opacity: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
  
  Color _getMockColor(bool isDarkMock, bool isSystem, {double opacity = 1.0}) {
    if (isSystem) return Colors.grey.withOpacity(opacity);
    return isDarkMock ? Colors.white.withOpacity(opacity) : Colors.black.withOpacity(opacity);
  }
}

class _DiagonalSplitPainter extends CustomPainter {
  final Color colorTopLeft;
  final Color colorBottomRight;

  _DiagonalSplitPainter({required this.colorTopLeft, required this.colorBottomRight});

  @override
  void paint(Canvas canvas, Size size) {
    final path1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    
    canvas.drawPath(path1, Paint()..color = colorTopLeft);

    final path2 = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    
    canvas.drawPath(path2, Paint()..color = colorBottomRight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.4, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.8)
      ..lineTo(0, size.height * 0.9)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.8],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
