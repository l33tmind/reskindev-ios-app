import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _youtubeUrl = '';
  String _heroTitle = 'reskindev';
  String _heroDescription = 'Premium App Development Services';
  String _whatsappNumber = '';
  String _featuredAppUrl = 'https://play.google.com/store/apps/details?id=com.reskindevdotcom.habito&hl=en';
  String _featuredAppName = 'Habito - Habit Tracker';
  String _featuredAppDeveloper = 'reskindev';
  String _featuredAppIconUrl = 'https://play-lh.googleusercontent.com/7U4A3soerqX7j0xPCOwYyMmTUYWfQ0gWyCMVY1IXh37Vi6cGm945SQHF0b8kkcP0N-6X6yw5fJVUNnyfwQUc';
  
  String _servicesTitle = 'Explore Services';
  String _servicesSubtitle = 'Find the best services for your next project';

  String _footerEmail = 'support@reskindev.com';
  String _footerWebsite = 'reskindev.com';
  String _footerCopyright = 'reskindev';
  String _footerPhone = '';
  String _footerAddress = '';
  String _footerDescription = 'Professional app development services for your business.';

  double _serviceFee = 5.0;
  late ThemeMode _themeMode;
  bool _loading = true;
  bool _hasSeenOnboarding = false;

  double get serviceFee => _serviceFee;
  String get youtubeUrl => _youtubeUrl;
  String get heroTitle => _heroTitle;
  String get heroDescription => _heroDescription;
  String get whatsappNumber => _whatsappNumber;
  String get featuredAppUrl => _featuredAppUrl;
  String get featuredAppName => _featuredAppName;
  String get featuredAppDeveloper => _featuredAppDeveloper;
  String get featuredAppIconUrl => _featuredAppIconUrl;
  
  String get servicesTitle => _servicesTitle;
  String get servicesSubtitle => _servicesSubtitle;

  String get footerEmail => _footerEmail;
  String get footerWebsite => _footerWebsite;
  String get footerCopyright => _footerCopyright;
  String get footerPhone => _footerPhone;
  String get footerAddress => _footerAddress;
  String get footerDescription => _footerDescription;

  ThemeMode get themeMode => _themeMode;
  bool get loading => _loading;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  SettingsProvider(ThemeMode initialTheme) {
    _themeMode = initialTheme;
    _loadSettings();
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  void toggleTheme(bool isDark) async {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.setString('theme_mode', 'system');
    } else if (mode == ThemeMode.dark) {
      await prefs.setString('theme_mode', 'dark');
    } else {
      await prefs.setString('theme_mode', 'light');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      final themeStr = prefs.getString('theme_mode');
      if (themeStr != null) {
        if (themeStr == 'system') _themeMode = ThemeMode.system;
        else if (themeStr == 'dark') _themeMode = ThemeMode.dark;
        else _themeMode = ThemeMode.light;
      } else {
        final isDark = prefs.getBool('isDarkMode');
        if (isDark != null) {
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        }
      }
      final doc = await _firestore.collection('settings').doc('global').get();
      if (doc.exists) {
        final data = doc.data()!;
        _youtubeUrl = data['youtube_url'] ?? '';
        _heroTitle = data['hero_title'] ?? 'reskindev';
        _heroDescription = data['hero_description'] ?? 'Premium App Development Services';
        _whatsappNumber = data['whatsapp_number'] ?? '';
        _featuredAppUrl = data['featured_app_url'] ?? 'https://play.google.com/store/apps/details?id=com.reskindevdotcom.habito&hl=en';
        _featuredAppName = data['featured_app_name'] ?? 'Habito - Habit Tracker';
        _featuredAppDeveloper = data['featured_app_developer'] ?? 'reskindev';
        _featuredAppIconUrl = data['featured_app_icon_url'] ?? 'https://play-lh.googleusercontent.com/7U4A3soerqX7j0xPCOwYyMmTUYWfQ0gWyCMVY1IXh37Vi6cGm945SQHF0b8kkcP0N-6X6yw5fJVUNnyfwQUc';
        
        _servicesTitle = data['services_title'] ?? 'Explore Services';
        _servicesSubtitle = data['services_subtitle'] ?? 'Find the best services for your next project';

        _footerEmail = data['footer_email'] ?? 'support@reskindev.com';
        _footerWebsite = data['footer_website'] ?? 'reskindev.com';
        _footerCopyright = data['footer_copyright'] ?? 'reskindev';
        if (_footerCopyright.toLowerCase() == 'hire app developer') {
          _footerCopyright = 'Hire Professional Freelancer';
        }
        _footerPhone = data['footer_phone'] ?? '';
        _footerAddress = data['footer_address'] ?? '';
        _footerDescription = data['footer_description'] ?? 'Professional services for your business.';
        if (_footerDescription == 'Professional app development services for your business.') {
          _footerDescription = 'Professional services for your business.';
        }
        _serviceFee = (data['serviceFee'] as num?)?.toDouble() ?? 5.0;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading settings: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updateSettings({
    String? youtubeUrl, 
    String? heroTitle, 
    String? heroDescription, 
    String? whatsappNumber,
    String? featuredAppUrl,
    String? featuredAppName,
    String? featuredAppDeveloper,
    String? featuredAppIconUrl,
    String? servicesTitle,
    String? servicesSubtitle,
    String? footerEmail,
    String? footerWebsite,
    String? footerCopyright,
    String? footerPhone,
    String? footerAddress,
    String? footerDescription,
    double? serviceFee,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (youtubeUrl != null) {
        data['youtube_url'] = youtubeUrl;
        _youtubeUrl = youtubeUrl;
      }
      if (heroTitle != null) {
        data['hero_title'] = heroTitle;
        _heroTitle = heroTitle;
      }
      if (heroDescription != null) {
        data['hero_description'] = heroDescription;
        _heroDescription = heroDescription;
      }
      if (whatsappNumber != null) {
        data['whatsapp_number'] = whatsappNumber;
        _whatsappNumber = whatsappNumber;
      }
      if (featuredAppUrl != null) {
        data['featured_app_url'] = featuredAppUrl;
        _featuredAppUrl = featuredAppUrl;
      }
      if (featuredAppName != null) {
        data['featured_app_name'] = featuredAppName;
        _featuredAppName = featuredAppName;
      }
      if (featuredAppDeveloper != null) {
        data['featured_app_developer'] = featuredAppDeveloper;
        _featuredAppDeveloper = featuredAppDeveloper;
      }
      if (featuredAppIconUrl != null) {
        data['featured_app_icon_url'] = featuredAppIconUrl;
        _featuredAppIconUrl = featuredAppIconUrl;
      }
      if (servicesTitle != null) {
        data['services_title'] = servicesTitle;
        _servicesTitle = servicesTitle;
      }
      if (servicesSubtitle != null) {
        data['services_subtitle'] = servicesSubtitle;
        _servicesSubtitle = servicesSubtitle;
      }
      if (footerEmail != null) {
        data['footer_email'] = footerEmail;
        _footerEmail = footerEmail;
      }
      if (footerWebsite != null) {
        data['footer_website'] = footerWebsite;
        _footerWebsite = footerWebsite;
      }
      if (footerCopyright != null) {
        data['footer_copyright'] = footerCopyright;
        _footerCopyright = footerCopyright;
      }
      if (footerPhone != null) {
        data['footer_phone'] = footerPhone;
        _footerPhone = footerPhone;
      }
      if (footerAddress != null) {
        data['footer_address'] = footerAddress;
        _footerAddress = footerAddress;
      }
      if (footerDescription != null) {
        data['footer_description'] = footerDescription;
        _footerDescription = footerDescription;
      }
      if (serviceFee != null) {
        data['serviceFee'] = serviceFee;
        _serviceFee = serviceFee;
      }

      if (data.isNotEmpty) {
        await _firestore.collection('settings').doc('global').set(
          data,
          SetOptions(merge: true),
        );
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('Error updating settings: $e');
      rethrow;
    }
  }
}
