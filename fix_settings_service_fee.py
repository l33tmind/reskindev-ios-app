import re

with open('lib/providers/settings_provider.dart', 'r') as f:
    content = f.read()

# Add _serviceFee
old_theme = """  late ThemeMode _themeMode;
  bool _loading = true;"""
new_theme = """  double _serviceFee = 5.0;
  late ThemeMode _themeMode;
  bool _loading = true;"""
content = content.replace(old_theme, new_theme)

# Add getter
old_get_youtube = """  String get youtubeUrl => _youtubeUrl;"""
new_get_youtube = """  double get serviceFee => _serviceFee;
  String get youtubeUrl => _youtubeUrl;"""
content = content.replace(old_get_youtube, new_get_youtube)

# Add to _loadSettings
old_load = """        if (_footerDescription == 'Professional app development services for your business.') {
          _footerDescription = 'Professional services for your business.';
        }
      }
    } catch (e) {"""
new_load = """        if (_footerDescription == 'Professional app development services for your business.') {
          _footerDescription = 'Professional services for your business.';
        }
        _serviceFee = (data['serviceFee'] as num?)?.toDouble() ?? 5.0;
      }
    } catch (e) {"""
content = content.replace(old_load, new_load)

# Add to updateSettings
old_update_sig = """    String? footerPhone,
    String? footerAddress,
    String? footerDescription,
  }) async {"""
new_update_sig = """    String? footerPhone,
    String? footerAddress,
    String? footerDescription,
    double? serviceFee,
  }) async {"""
content = content.replace(old_update_sig, new_update_sig)

old_update_body = """      if (footerDescription != null) {
        data['footer_description'] = footerDescription;
        _footerDescription = footerDescription;
      }

      if (data.isNotEmpty) {"""
new_update_body = """      if (footerDescription != null) {
        data['footer_description'] = footerDescription;
        _footerDescription = footerDescription;
      }
      if (serviceFee != null) {
        data['serviceFee'] = serviceFee;
        _serviceFee = serviceFee;
      }

      if (data.isNotEmpty) {"""
content = content.replace(old_update_body, new_update_body)

with open('lib/providers/settings_provider.dart', 'w') as f:
    f.write(content)

print("Updated SettingsProvider with serviceFee")
