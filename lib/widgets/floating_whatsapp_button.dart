import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FloatingWhatsAppButton extends StatefulWidget {
  final String title;
  final String? whatsappNumber;
  final bool isGigScreen;

  const FloatingWhatsAppButton({
    super.key,
    this.title = '',
    this.whatsappNumber,
    this.isGigScreen = false,
  });

  @override
  State<FloatingWhatsAppButton> createState() => _FloatingWhatsAppButtonState();
}

class _FloatingWhatsAppButtonState extends State<FloatingWhatsAppButton> {
  bool _isHovered = false;

  Future<void> _launchWhatsApp() async {
    Uri url;
    String number = '';
    
    if (widget.whatsappNumber != null && widget.whatsappNumber!.isNotEmpty) {
      number = widget.whatsappNumber!.replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
    }

    if (widget.isGigScreen) {
      url = Uri.parse('https://wa.me/$number?text=Hello%2C%20I%20am%20interested%20in%20your%20service%3A%20${Uri.encodeComponent(widget.title)}');
    } else {
      url = Uri.parse('https://wa.me/$number?text=Hello%2C%20I%20am%20interested%20in%20your%20services!');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48, right: 24),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: _launchWhatsApp,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            width: _isHovered ? 72 : 62,
            height: _isHovered ? 72 : 62,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withOpacity(_isHovered ? 0.6 : 0.45),
                  blurRadius: _isHovered ? 30 : 24,
                  spreadRadius: _isHovered ? 4 : 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
                size: _isHovered ? 44 : 38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
