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
import '../widgets/user_avatar.dart';
import '../widgets/pro_badge.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
        backgroundColor: context.themeSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            // User Header Card
            if (auth.user == null)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.themeSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 64, color: context.themeTextLight.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('Not Signed In', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                    const SizedBox(height: 4),
                    Text('Sign in to order, chat and sell.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextLight)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/login'),
                        icon: const Icon(Icons.login, size: 20),
                        label: Text('Sign In / Register', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.themeSurface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    // Tap to add or change the profile photo (it shows in chats, inbox and orders)
                    GestureDetector(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final done = await context.read<ap.AuthProvider>().pickAndUploadProfilePhoto(
                            onUploading: () => messenger.showSnackBar(
                              const SnackBar(content: Text('Uploading photo…'), duration: Duration(seconds: 20)),
                            ),
                          );
                          messenger.hideCurrentSnackBar();
                          if (done) messenger.showSnackBar(const SnackBar(content: Text('Profile photo updated')));
                        } catch (e) {
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(SnackBar(content: Text('Could not update the photo: $e'), backgroundColor: AppTheme.error));
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(
                            uid: auth.user?.uid,
                            name: auth.user?.displayName ?? '',
                            photoUrl: auth.photoUrl.isNotEmpty ? auth.photoUrl : null,
                            radius: 36,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: context.themeSurface, width: 2),
                              ),
                              child: const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  auth.user?.displayName ?? 'No Name',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: context.themeTextDark),
                                ),
                              ),
                              if (auth.isPro) ...[
                                const SizedBox(width: 8),
                                const ProBadge(fontSize: 11),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            auth.username != null ? '@${auth.username}' : (auth.user?.email ?? 'No email'),
                            style: GoogleFonts.inter(fontSize: 14, color: context.themeTextLight),
                          ),
                          if (auth.reviewCount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${auth.averageRating.toStringAsFixed(1)} (${auth.reviewCount} reviews)',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: context.themeTextDark),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const _EditProfileSheet(),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      color: AppTheme.primary,
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            if (auth.user != null) ...[
              // Group 1: Account & Earnings
              _buildSectionHeader(context, 'Account & Earnings'),
              _buildSettingsCard(context, [
                _buildListTile(
                  context: context,
                  icon: Icons.bolt_rounded,
                  iconColor: ProBadge.amber,
                  title: 'Reskindev Pro',
                  subtitle: auth.isPro ? 'PRO badge, message any seller, media in every chat' : 'Get the PRO badge and more',
                  onTap: () => context.push('/pro'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (auth.isPro)
                        Text('Active', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success))
                      else
                        const ProBadge(fontSize: 10.5),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 16, color: context.themeTextLight.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _buildListTile(
                  context: context,
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const _EditProfileSheet(),
                    );
                  },
                  showArrow: true,
                ),
                const Divider(height: 1),
                _buildListTile(
                  context: context,
                  icon: Icons.account_balance_wallet_rounded,
                  title: auth.role == 'freelancer' || auth.isAdmin ? 'Wallet & Earnings' : 'Wallet',
                  onTap: () => context.push('/wallet'),
                  showArrow: true,
                ),
                  const Divider(height: 1),
                                    _buildListTile(
                    context: context,
                    icon: Icons.storefront_outlined,
                    title: auth.isSellerMode ? 'Switch to Buying' : 'Switch to Seller Mode',
                    subtitle: auth.isSellerMode ? 'Browse and order services' : 'Sell your services and manage orders',
                    onTap: () {
                        final newValue = !auth.isSellerMode;
                        context.read<ap.AuthProvider>().toggleSellerMode(newValue);
                        if (newValue) {
                            context.go('/seller');
                        } else {
                            context.go('/my-orders');
                        }
                    },
                    trailing: Switch(
                        value: auth.isSellerMode,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                            context.read<ap.AuthProvider>().toggleSellerMode(val);
                            if (val) {
                                context.go('/seller');
                            } else {
                                context.go('/my-orders');
                            }
                        },
                    ),
                  ),

                if (auth.isAdmin) ...[
                  const Divider(height: 1),
                  // Red count = orders waiting for payment verification + gigs waiting for approval
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('orders')
                        .where('status', whereIn: ['pending_payment', 'pending']).snapshots(),
                    builder: (context, orderSnap) => StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('services')
                          .where('status', isEqualTo: 'pending').snapshots(),
                      builder: (context, gigSnap) {
                        final waiting = (orderSnap.data?.docs.length ?? 0) + (gigSnap.data?.docs.length ?? 0);
                        return _buildListTile(
                          context: context,
                          icon: Icons.grid_view_rounded,
                          title: 'Admin Dashboard',
                          subtitle: waiting > 0 ? '$waiting waiting for you' : null,
                          onTap: () => context.push('/admin'),
                          trailing: waiting > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(12)),
                                  child: Text('$waiting', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                                )
                              : null,
                          showArrow: waiting == 0,
                        );
                      },
                    ),
                  ),
                ],
                if (auth.role == 'freelancer' || auth.isAdmin) ...[
                  const Divider(height: 1),
                  _buildListTile(
                    context: context,
                    icon: Icons.chat_bubble_outline,
                    title: 'Quick Replies',
                    onTap: () => context.push('/quick-replies'),
                    showArrow: true,
                  ),
                ],
              ]),
              const SizedBox(height: 24),
            ],
            
            // Group 2: App Settings
            _buildSectionHeader(context, 'App Settings'),
            _buildSettingsCard(context, [
              _buildListTile(
                context: context,
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => context.push('/appearance'),
                showArrow: true,
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Group 3: Support & Legal
            _buildSectionHeader(context, 'Support & Legal'),
            _buildSettingsCard(context, [
              _buildListTile(
                context: context,
                icon: Icons.info_outline,
                title: 'Contact Us',
                onTap: () => context.push('/page/contact'),
                showArrow: true,
              ),
              const Divider(height: 1),
              _buildListTile(
                context: context,
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push('/page/privacy-policy'),
                showArrow: true,
              ),
              const Divider(height: 1),
              _buildListTile(
                context: context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => context.push('/page/terms'),
                showArrow: true,
              ),
              const Divider(height: 1),
              _buildListTile(
                context: context,
                icon: Icons.currency_exchange_outlined,
                title: 'Refund Policy',
                onTap: () => context.push('/page/refund-and-cancellation-policy'),
                showArrow: true,
              ),
              const Divider(height: 1),
              _buildListTile(
                context: context,
                icon: Icons.star_border,
                title: 'Rate Us',
                onTap: () => _handleRateUs(context),
                showArrow: false, // Actions like rating shouldn't have arrows
              ),
            ]),
            
            const SizedBox(height: 24),
            
            if (auth.user != null) ...[
              // Group 4: Danger Zone
              _buildSectionHeader(context, 'Account Management', isDanger: true),
              _buildSettingsCard(context, [
                _buildListTile(
                  context: context,
                  icon: Icons.person_remove_outlined,
                  title: 'Delete Account',
                  isDanger: true,
                  onTap: () => _handleDeleteAccount(context, auth),
                  showArrow: false,
                ),
                const Divider(height: 1),
                _buildListTile(
                  context: context,
                  icon: Icons.logout,
                  title: 'Sign Out',
                  isDanger: true,
                  onTap: () => auth.signOut(),
                  showArrow: false,
                ),
              ]),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDanger ? Colors.red : context.themeTextLight,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.themeBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showArrow = false,
    bool isDanger = false,
    Widget? trailing,
    String? subtitle,
    Color? iconColor,
  }) {
    final color = isDanger ? Colors.red : context.themeTextDark;
    iconColor ??= isDanger ? Colors.red : AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: color),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: context.themeTextLight)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing
              else if (showArrow)
                Icon(Icons.arrow_forward_ios, size: 16, color: context.themeTextLight.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRateUs(BuildContext context) async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing(appStoreId: '6670553038');
      }
    } catch (e) {
      try {
        final isAndroid = Theme.of(context).platform == TargetPlatform.android;
        final url = Uri.parse(
          isAndroid 
              ? 'market://details?id=com.reskindevdotcom.reskindev'
              : 'https://apps.apple.com/app/id6670553038'
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          final webUrl = Uri.parse(
            isAndroid
                ? 'https://play.google.com/store/apps/details?id=com.reskindevdotcom.reskindev'
                : 'https://apps.apple.com/app/id6670553038'
          );
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } catch (e2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open store listing.')),
          );
        }
      }
    }
  }

  void _handleDeleteAccount(BuildContext context, ap.AuthProvider auth) {
    String confirmText = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: context.themeSurface,
            title: Text('Delete Account', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.themeTextDark)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to permanently delete your account? This action cannot be undone.',
                  style: GoogleFonts.inter(color: context.themeTextLight),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type "confirm" to proceed:',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.themeTextDark),
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (val) {
                    setState(() {
                      confirmText = val.toLowerCase().trim();
                    });
                  },
                  style: GoogleFonts.inter(color: context.themeTextDark),
                  decoration: InputDecoration(
                    hintText: 'confirm',
                    hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: context.themeBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: confirmText == 'confirm' ? () async {
                  Navigator.pop(ctx);
                  try {
                    await auth.deleteAccount();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not delete account. You may need to log out and log in again first.')),
                      );
                    }
                  }
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}

// ==========================================
// Edit Profile Form Logic (Bottom Sheet)
// ==========================================
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _usernameCtrl;
  
  bool _saving = false;
  
  bool _isCheckingUsername = false;
  String? _usernameError;
  String _usernameStatus = 'idle'; // idle, checking, taken, available
  bool _canChangeUsername = true;

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
    final auth = context.read<ap.AuthProvider>();
    if (_usernameStatus == 'taken' && _usernameCtrl.text != auth.username) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose an available username.')));
      return;
    }

    setState(() => _saving = true);
    
    final newUsername = _usernameCtrl.text.toLowerCase().trim();
    if (newUsername != auth.username && _canChangeUsername && newUsername.isNotEmpty) {
      final uid = auth.user?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'usernameChanges': FieldValue.arrayUnion([DateTime.now().millisecondsSinceEpoch])
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Error updating usernameChanges: $e');
        }
      }
    }

    try {
      await auth.updateProfile(
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        username: newUsername.isEmpty ? null : newUsername,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        company: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    }
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
    final auth = context.watch<ap.AuthProvider>();
    
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: context.themeTextLight,
                )
              ],
            ),
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
                  readOnly: !_canChangeUsername && _usernameCtrl.text != auth.username,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
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
