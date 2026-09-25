import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/settings_provider.dart';
import '../providers/page_provider.dart';
import '../theme.dart';
import '../widgets/web_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _usernameCtrl;
  
  bool _saving = false;
  bool _saved = false;
  
  bool _isCheckingUsername = false;
  String? _usernameError;
  String _usernameStatus = 'idle'; // idle, checking, taken, available
  bool _canChangeUsername = true;
  DateTime? _lastUsernameChange;

  @override
void initState() {
    super.initState();
    final auth = context.read<ap.AuthProvider>();
    _nameCtrl = TextEditingController(text: auth.user?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: auth.phone ?? '');
    _companyCtrl = TextEditingController(text: auth.company ?? '');
    _addressCtrl = TextEditingController(text: auth.address ?? '');
    _usernameCtrl = TextEditingController(text: auth.username ?? '');
    _checkUsernameLimit();
  }
  
  Future<void> _checkUsernameLimit() async {
    final uid = context.read<ap.AuthProvider>().user?.uid;
    if (uid == null) return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final changes = doc.data()?['usernameChanges'] as List<dynamic>? ?? [];
      if (changes.isNotEmpty) {
        final lastChangeRaw = changes.last;
        DateTime? lastChange;
        if (lastChangeRaw is Timestamp) lastChange = lastChangeRaw.toDate();
        else if (lastChangeRaw is int) lastChange = DateTime.fromMillisecondsSinceEpoch(lastChangeRaw);
        
        if (lastChange != null) {
          final now = DateTime.now();
          if (now.difference(lastChange).inDays < 30) {
            if (mounted) {
              setState(() {
                _canChangeUsername = false;
                _lastUsernameChange = lastChange;
              });
            }
          }
        }
      }
    }
  }
  
  void _onUsernameChanged(String value) async {
    if (value == context.read<ap.AuthProvider>().username) {
      setState(() {
        _usernameError = null;
        _usernameStatus = 'idle';
      });
      return;
    }
    
    if (!_canChangeUsername) return;
    
    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });
    
    final query = await FirebaseFirestore.instance.collection('users').where('username', isEqualTo: value.toLowerCase()).get();
    if (mounted) {
      setState(() {
        _isCheckingUsername = false;
        if (query.docs.isNotEmpty) {
          _usernameError = 'Username is already taken';
          _usernameStatus = 'taken';
        } else {
          _usernameError = 'Username is available';
          _usernameStatus = 'available';
        }
      });
    }
  }

  @override
void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _addressCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_usernameStatus == 'taken' && _usernameCtrl.text != context.read<ap.AuthProvider>().username) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose an available username.')));
      return;
    }

    setState(() => _saving = true);
    
    final newUsername = _usernameCtrl.text.toLowerCase().trim();
    if (newUsername != context.read<ap.AuthProvider>().username && _canChangeUsername && newUsername.isNotEmpty) {
      final uid = context.read<ap.AuthProvider>().user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'usernameChanges': FieldValue.arrayUnion([FieldValue.serverTimestamp()])
        });
      }
    }

    await context.read<ap.AuthProvider>().updateProfile(
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      username: newUsername.isEmpty ? null : newUsername,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
    );
    
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  Widget _buildField({
    required TextEditingController controller,
    List<TextInputFormatter>? inputFormatters,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    Widget? suffix,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: context.themeBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Information', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark)),
            const SizedBox(height: 8),
            Text('These details are auto-filled in orders.', style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight)),
            const SizedBox(height: 24),
            _buildField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_outline),
            const SizedBox(height: 16),
            
            _buildField(
                  controller: _usernameCtrl, 
                  label: 'Username', 
                  icon: Icons.alternate_email,
                  onChanged: _onUsernameChanged,
                  readOnly: !_canChangeUsername && _usernameCtrl.text != context.read<ap.AuthProvider>().username,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  ],
                  suffix: _isCheckingUsername 
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
                        )
                      : null,
                ),
                if (_usernameError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 16),
                    child: Text(
                      _usernameError!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _usernameStatus == 'taken' ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                if (!_canChangeUsername && _usernameError == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 16),
                    child: Text(
                      'You have reached the limit of 1 username change in 30 days.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
                    ),
                  ),
            const SizedBox(height: 16),
            
            _buildField(controller: _phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildField(controller: _companyCtrl, label: 'Company Name', icon: Icons.business_outlined),
            const SizedBox(height: 16),
            _buildField(controller: _addressCtrl, label: 'Address', icon: Icons.location_on_outlined, maxLines: 2),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
