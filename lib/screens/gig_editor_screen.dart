import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:in_app_review/in_app_review.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' as img_picker;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../models/gig_model.dart';
import '../providers/auth_provider.dart' as ap;

class GigEditorScreen extends StatefulWidget {
  final GigModel? gig;
  const GigEditorScreen({super.key, this.gig});

  @override
  State<GigEditorScreen> createState() => _GigEditorScreenState();
}

// Helper class to hold controllers for each dynamic package tier
class _PackageTierControllers {
  TextEditingController nameCtrl;
  TextEditingController priceCtrl;
  TextEditingController descCtrl;
  TextEditingController deliveryCtrl;

  _PackageTierControllers({
    String name = '',
    String price = '0',
    String desc = '',
    String delivery = '3',
  })  : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price),
        descCtrl = TextEditingController(text: desc),
        deliveryCtrl = TextEditingController(text: delivery);

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    deliveryCtrl.dispose();
  }
}

class _CouponState {
  TextEditingController codeCtrl;
  TextEditingController discountCtrl;
  
  _CouponState({String code = '', String discount = '0'})
      : codeCtrl = TextEditingController(text: code),
        discountCtrl = TextEditingController(text: discount);

  void dispose() {
    codeCtrl.dispose();
    discountCtrl.dispose();
  }
}

class _GigEditorScreenState extends State<GigEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  // Tags/Keywords
  late TextEditingController _tagInputCtrl;
  List<String> _tags = [];
  
  // Single smart media field: accepts image URL or YouTube URL
  late TextEditingController _youtubeCtrl;
  String _uploadedImageUrl = '';
  bool _isUploadingImage = false;
  late TextEditingController _whatsappCtrl;
  
  // Gallery images simple state
  List<TextEditingController> _galleryCtrls = [];
  
  // Premium Gallery Config
  late TextEditingController _galleryUnlockPriceCtrl;
  late TextEditingController _deliveryCostCtrl;
  List<_CouponState> _galleryCoupons = [];

  // Dynamic Package Tiers
  List<_PackageTierControllers> _tiers = [];

  // Features Matrix
  List<String> _masterFeatures = [];
  // featureChecks[tierIndex][featureName] = true/false
  List<Map<String, bool>> _tierFeatureChecks = [];
  
  final TextEditingController _newFeatureCtrl = TextEditingController();

  bool _isSaving = false;
  bool _agreedToTerms = false;
  String _status = 'active';
  String _selectedCategory = '';
  List<String> _categories = [];
  bool _ugcAccepted = false;
  int _selectedTierIndex = 0;

  // Tier color palette for visual distinction
  static const List<Color> _tierColors = [
    Color(0xFF10B981), // Emerald (Basic)
    Color(0xFF3B82F6), // Blue (Standard)
    Color(0xFFF59E0B), // Amber (Premium)
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
  ];

  Color _colorForTier(int index) => _tierColors[index % _tierColors.length];

  Future<void> _fetchCategories() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('categories').get();
      if (doc.exists && doc.data()!.containsKey('list')) {
        setState(() {
          _categories = List<String>.from(doc.data()!['list']);
          if (_selectedCategory.isEmpty && _categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    
    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      var uri = Uri.parse("https://api.reskindev.com/upload.php");
      var request = http.MultipartRequest("POST", uri);
      
      // Attach the image file
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      
      // Attach the freelancer ID
      request.fields['freelancer_id'] = user.uid;
      
      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _uploadedImageUrl = jsonResponse['url'];
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded successfully!'), backgroundColor: Colors.green));
          }
        } else {
          throw Exception(jsonResponse['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    final g = widget.gig;
    _selectedCategory = g?.category ?? '';
    _titleCtrl = TextEditingController(text: g?.title ?? '');
    _descCtrl = TextEditingController(text: g?.description ?? '');
    _tagInputCtrl = TextEditingController();
    _tags = g?.keywords != null ? List.from(g!.keywords) : [];
    // YouTube URL takes priority; if no YouTube, use imageUrl
    _youtubeCtrl = TextEditingController(text: g?.youtubeUrl ?? '');
    _uploadedImageUrl = g?.imageUrl ?? '';
    _whatsappCtrl = TextEditingController(text: g?.whatsappNumber ?? '');
    
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = user?.uid == 'md-robius-sany' || user?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com';
    
    String initStatus = g?.status ?? 'pending';
    if (isAdmin) {
      if (initStatus != 'active' && initStatus != 'pending' && initStatus != 'paused') {
        initStatus = 'active';
      }
    } else {
      initStatus = 'pending';
    }
    _status = initStatus;

    for (var img in (g?.galleryImages ?? [])) {
      _galleryCtrls.add(TextEditingController(text: img));
    }

    _galleryUnlockPriceCtrl = TextEditingController(text: g?.galleryUnlockPrice.toString() ?? '0');
    _deliveryCostCtrl = TextEditingController(text: g?.deliveryCost.toString() ?? '0');
    g?.galleryCoupons.forEach((code, discount) {
      _galleryCoupons.add(_CouponState(code: code, discount: discount.toString()));
    });

    // Load existing packages or create defaults
    if (g != null && g.packages.isNotEmpty) {
      // Load existing tiers
      for (var pkg in g.packages) {
        _tiers.add(_PackageTierControllers(
          name: pkg.name,
          price: pkg.price.toString(),
          desc: pkg.description,
          delivery: pkg.deliveryDays.toString(),
        ));
        _tierFeatureChecks.add({}); // Ensure a map exists for each tier
      }

      // Load features
      if (g.masterFeatures.isNotEmpty) {
        _masterFeatures = List.from(g.masterFeatures);
        for (int t = 0; t < _tiers.length; t++) {
          for (int i = 0; i < _masterFeatures.length; i++) {
            final featName = _masterFeatures[i];
            bool isChecked = false;
            if (t < g.packages.length && i < g.packages[t].featureChecks.length) {
              isChecked = g.packages[t].featureChecks[i];
            }
            _tierFeatureChecks[t][featName] = isChecked;
          }
        }
      }
    } else {
      // Default: Basic + Standard
      _tiers.add(_PackageTierControllers(name: 'Basic', price: '150', desc: 'Basic features setup.', delivery: '3'));
      _tiers.add(_PackageTierControllers(name: 'Standard', price: '250', desc: 'Standard professional features setup.', delivery: '5'));
      _tierFeatureChecks.add({});
      _tierFeatureChecks.add({});

      // Default features
      _addFeature('High Definition Output', defaults: [true, true]);
      _addFeature('Source Code', defaults: [false, true]);
      _addFeature('Revisions Included', defaults: [true, true]);
    }
  }

  void _addTier() {
    setState(() {
      _tiers.add(_PackageTierControllers(name: '', price: '0', desc: '', delivery: '3'));
      // Add feature checks for the new tier (all unchecked)
      final checks = <String, bool>{};
      for (var feat in _masterFeatures) {
        checks[feat] = false;
      }
      _tierFeatureChecks.add(checks);
    });
  }

  void _removeTier(int index) {
    if (_tiers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one package tier.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      _tiers[index].dispose();
      _tiers.removeAt(index);
      _tierFeatureChecks.removeAt(index);
    });
  }

  void _addFeature(String name, {List<bool>? defaults}) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || _masterFeatures.contains(cleanName)) return;
    setState(() {
      _masterFeatures.add(cleanName);
      for (int t = 0; t < _tiers.length; t++) {
        if (t < _tierFeatureChecks.length) {
          _tierFeatureChecks[t][cleanName] = (defaults != null && t < defaults.length) ? defaults[t] : false;
        }
      }
    });
  }

  void _removeFeature(String name) {
    setState(() {
      _masterFeatures.remove(name);
      for (var checks in _tierFeatureChecks) {
        checks.remove(name);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagInputCtrl.dispose();
    _youtubeCtrl.dispose();
    _whatsappCtrl.dispose();
    for (var c in _galleryCtrls) c.dispose();
    _galleryUnlockPriceCtrl.dispose();
    _deliveryCostCtrl.dispose();
    for (var c in _galleryCoupons) c.dispose();
    for (var t in _tiers) t.dispose();
    _newFeatureCtrl.dispose();
    super.dispose();
  }

  // Auto-detect if URL is YouTube
  static bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/embed/');
  }

  // Extract YouTube video ID from URL
  static String? _extractVideoId(String url) {
    if (url.contains('v=')) {
      final id = url.split('v=')[1];
      final amp = id.indexOf('&');
      return amp != -1 ? id.substring(0, amp) : id;
    }
    if (url.contains('youtu.be/')) {
      final id = url.split('youtu.be/')[1];
      final q = id.indexOf('?');
      return q != -1 ? id.substring(0, q) : id;
    }
    return null;
  }

  void _addMasterFeature() {
    final text = _newFeatureCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_masterFeatures.contains(text)) {
      setState(() {
        _masterFeatures.add(text);
        for (var checkMap in _tierFeatureChecks) {
          checkMap[text] = false;
        }
      });
    }
    _newFeatureCtrl.clear();
  }
  
  Future<void> _save() async {

    if (!_formKey.currentState!.validate()) return;
    
    if ((_uploadedImageUrl.isNotEmpty || _youtubeCtrl.text.trim().isNotEmpty) && !_ugcAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept the Mandatory UGC & Copyright Declaration.'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSaving = true);


    try {
      final packages = <GigPackage>[];
      for (int t = 0; t < _tiers.length; t++) {
        final tier = _tiers[t];
        final featureChecks = _masterFeatures.map((f) => _tierFeatureChecks[t][f] ?? false).toList();
        packages.add(GigPackage(
          name: tier.nameCtrl.text.trim().isEmpty ? 'Tier ${t + 1}' : tier.nameCtrl.text.trim(),
          price: double.tryParse(tier.priceCtrl.text) ?? 0,
          description: tier.descCtrl.text,
          deliveryDays: int.tryParse(tier.deliveryCtrl.text) ?? 3,
          featureChecks: featureChecks,
        ));
      }

      final List<String> gallery = _galleryCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

      String imageUrl = _uploadedImageUrl;
      String? youtubeUrl = _youtubeCtrl.text.trim().isNotEmpty ? _youtubeCtrl.text.trim() : null;
      if (youtubeUrl != null && imageUrl.isEmpty) {
        final videoId = _extractVideoId(youtubeUrl);
        // Auto-generate thumbnail URL from YouTube only if no custom image
        imageUrl = videoId != null
            ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
            : '';
      }

      final Map<String, double> couponMap = {};
      for (var c in _galleryCoupons) {
        final code = c.codeCtrl.text.trim();
        final discount = double.tryParse(c.discountCtrl.text.trim()) ?? 0;
        if (code.isNotEmpty) {
          couponMap[code] = discount;
        }
      }

      // Get current user info for authorId/authorName
      final authProvider = context.read<ap.AuthProvider>();
      final currentUser = FirebaseAuth.instance.currentUser;
      final authorId = widget.gig?.authorId.isNotEmpty == true
          ? widget.gig!.authorId
          : (currentUser?.uid ?? '');
      
      String authorName = widget.gig?.authorName ?? '';
      if (authorName.isEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            authorName = data['displayName'] ?? data['name'] ?? '';
          }
        } catch (_) {}
      }
      
      if (authorName.isEmpty) {
        authorName = authProvider.displayName.isNotEmpty
            ? authProvider.displayName
            : (currentUser?.displayName ?? currentUser?.email ?? '');
      }

      // Generate slug from title
      final slug = _titleCtrl.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '-');

      final user = FirebaseAuth.instance.currentUser;
      final isAdmin = user?.uid == 'md-robius-sany' || user?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com';
      if (!isAdmin) {
        _status = 'pending';
      }

      final Map<String, dynamic> gigData = {
        'title': _titleCtrl.text,
        'slug': slug,
        'description': _descCtrl.text,
        'tags': _tags,
        'imageUrl': imageUrl,
        'images': imageUrl.isNotEmpty ? [imageUrl] : [],
        'youtubeUrl': youtubeUrl,
        'whatsappNumber': _whatsappCtrl.text.isNotEmpty ? _whatsappCtrl.text : null,
        'galleryImages': gallery,
        'galleryUnlockPrice': double.tryParse(_galleryUnlockPriceCtrl.text) ?? 0,
        'deliveryCost': double.tryParse(_deliveryCostCtrl.text) ?? 0,
        'galleryCoupons': couponMap,
        'masterFeatures': _masterFeatures,
        'packages': packages.map((p) => p.toMap()).toList(),
        'status': _status,
        'authorId': authorId,
        'authorName': authorName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.gig == null) {
        gigData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('services').add(gigData);
      } else {
        await FirebaseFirestore.instance.collection('services').doc(widget.gig!.id).update(gigData);
      }

      if (!mounted) return;
      
      if (widget.gig == null) {
        // Show smooth success + rating popup
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 64),
                  const SizedBox(height: 16),
                  Text('Gig Created!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                  const SizedBox(height: 8),
                  Text('Your service is now live. If you enjoy using our app, please take a moment to rate us!', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700], height: 1.4)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx); // Close dialog
                        Navigator.pop(context); // Close editor
                        try {
                          final InAppReview inAppReview = InAppReview.instance;
                          if (await inAppReview.isAvailable()) {
                            await inAppReview.requestReview();
                          }
                        } catch (e) {
                           debugPrint('Rating error: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Rate App', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context); // Close editor
                    },
                    child: Text('Maybe Later', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  )
                ],
              ),
            ),
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service updated successfully!'), backgroundColor: AppTheme.primary),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: BoxDecoration(
            color: context.themeSurface,
            border: Border(bottom: BorderSide(color: context.themeBorder)),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.gig != null ? 'Edit Gig Details' : 'Add New Gig',
                      style: GoogleFonts.outfit(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.w800,
                          color: context.themeTextDark),
                    ),
                    Text('Modify service price, preview media, and description text',
                        style: GoogleFonts.inter(
                            fontSize: isMobile ? 10 : 12, color: context.themeTextLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (!isMobile) const Spacer(),
              if (!isMobile)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to Dashboard'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.themeTextDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: context.themeBorder),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 40, horizontal: isMobile ? 16 : 0),
            child: Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  color: context.themeSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.5),
                ),
                padding: EdgeInsets.all(isMobile ? 16 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      _buildTextField(_titleCtrl, 'Service Title', 'e.g. Video Editing'),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Visibility Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _status,
                            items: [
                              if (FirebaseAuth.instance.currentUser?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com' || FirebaseAuth.instance.currentUser?.uid == 'md-robius-sany')
                              DropdownMenuItem(
                                value: 'active',
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text('ACTIVE (Admin Only)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'draft',
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text('DRAFT', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'pending',
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text('SUBMIT FOR APPROVAL', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) => setState(() => _status = val ?? 'pending'),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.themeSurface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.15))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.15))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(_titleCtrl, 'Service Title', 'e.g. Video Editing'),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visibility Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _status,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'active',
                                      child: Row(
                                        children: [
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Text('ACTIVE', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'draft',
                                      child: Row(
                                        children: [
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Text('DRAFT', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Row(
                                        children: [
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Text('SUBMIT FOR APPROVAL', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) => setState(() => _status = val ?? 'pending'),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: context.themeSurface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.15))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.15))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Media'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thumbnail Image', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.themeSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black.withOpacity(0.15)),
                              image: _uploadedImageUrl.isNotEmpty 
                                ? DecorationImage(image: NetworkImage(_uploadedImageUrl), fit: BoxFit.cover)
                                : null,
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator.adaptive())
                                : _uploadedImageUrl.isEmpty
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 40, color: context.themeTextLight),
                                          const SizedBox(height: 8),
                                          Text('Tap to upload image', style: GoogleFonts.inter(color: context.themeTextLight)),
                                        ],
                                      )
                                    : Align(
                                        alignment: Alignment.topRight,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                          onPressed: () => setState(() => _uploadedImageUrl = ''),
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_youtubeCtrl, 'YouTube Video URL (Optional)', 'e.g. https://youtu.be/...'),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _youtubeCtrl,
                          builder: (context, value, child) {
                            if (_uploadedImageUrl.isNotEmpty || value.text.trim().isNotEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                                ),
                                child: CheckboxListTile(
                                  value: _ugcAccepted,
                                  onChanged: (val) {
                                    setState(() => _ugcAccepted = val ?? false);
                                  },
                                  title: Text(
                                    'Mandatory UGC & Copyright Declaration',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red.shade700),
                                  ),
                                  subtitle: Text(
                                    'I confirm this video is uploaded as "Unlisted" on YouTube. I acknowledge that I am submitting User-Generated Content (UGC) and warrant that I own all intellectual property rights to this video. I agree not to submit any copyrighted, objectionable, or abusive material. I grant Reskindev permission to embed this video and assume full legal liability for its content.',
                                    style: GoogleFonts.inter(fontSize: 12, color: context.themeTextDark),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: Colors.red.shade700,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── PACKAGE TIERS (TABS) ──────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildSectionTitleInline('Packages & Features')),
                        const SizedBox(width: 8),
                        if (_tiers.length < 3)
                          ElevatedButton.icon(
                            onPressed: _addTier,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Tier'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    

                    if (_tiers.isNotEmpty) ...[
                      // Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_tiers.length, (index) {
                            final tier = _tiers[index];
                            final isSelected = _selectedTierIndex == index;
                            final color = _colorForTier(index);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(tier.nameCtrl.text.isEmpty ? 'Tier ${index+1}' : tier.nameCtrl.text),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedTierIndex = index);
                                },
                                selectedColor: color.withValues(alpha: 0.15),
                                labelStyle: GoogleFonts.inter(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? color : context.themeTextLight,
                                ),
                                side: BorderSide(color: isSelected ? color : context.themeBorder),
                                backgroundColor: context.themeSurface,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Active Tier Form
                      Builder(
                        builder: (context) {
                          if (_selectedTierIndex >= _tiers.length) _selectedTierIndex = _tiers.length - 1;
                          final idx = _selectedTierIndex;
                          final tier = _tiers[idx];
                          final color = _colorForTier(idx);
                          
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.themeSurface,
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField(tier.nameCtrl, 'Package Name', 'e.g. Basic')),
                                    if (_tiers.length > 1) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            _tiers.removeAt(idx);
                                            _tierFeatureChecks.removeAt(idx);
                                            _selectedTierIndex = 0;
                                          });
                                        },
                                      ),
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField(tier.priceCtrl, 'Price (USD)', '0.0', isNumber: true)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildTextField(tier.deliveryCtrl, 'Delivery (Days)', '3', isNumber: true)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(tier.descCtrl, 'Package Description', 'What is included in this package?', maxLines: 2),
                                
                                const SizedBox(height: 24),
                                Text('Features Included', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: context.themeTextDark)),
                                const SizedBox(height: 12),
                                
                                if (_masterFeatures.isEmpty)
                                  Text('No features added yet.', style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
                                  
                                ..._masterFeatures.asMap().entries.map((fEntry) {
                                  final fIdx = fEntry.key;
                                  final feature = fEntry.value;
                                  final isIncluded = _tierFeatureChecks[idx][feature] ?? false;
                                  
                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    dense: true,
                                    activeColor: color,
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(feature, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark))),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              _masterFeatures.removeAt(fIdx);
                                              for (var checkMap in _tierFeatureChecks) {
                                                checkMap.remove(feature);
                                              }
                                            });
                                          },
                                        )
                                      ],
                                    ),
                                    value: isIncluded,
                                    onChanged: (val) {
                                      setState(() {
                                        _tierFeatureChecks[idx][feature] = val ?? false;
                                      });
                                    },
                                  );
                                }),
                                
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _newFeatureCtrl,
                                        style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark),
                                        decoration: InputDecoration(
                                          hintText: 'Add new feature (e.g. Source Code)',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onSubmitted: (_) => _addMasterFeature(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _addMasterFeature,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],

                    _buildSectionTitle('Gig Description'),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 10,
                      style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 13, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Write a clear and simple description of what you offer...',
                        fillColor: context.themeSurface,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.black12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle('Search Tags / Keywords'),
                    _buildTagsSection(context),

                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _agreedToTerms,
                      onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                      title: Text(
                        'I agree to the Terms of Service and confirm this service contains no abusive, copyright-infringing, or objectionable content.',
                        style: GoogleFonts.inter(fontSize: 13, color: context.themeTextDark),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                            child: Text('Cancel', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (!_agreedToTerms || _isSaving) ? null : _save,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                            child: _isSaving
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                                : Text('Save Service', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark)),
    );
  }

  Widget _buildSectionTitleInline(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: context.themeTextDark));
  }

  Widget _buildTagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add up to 5 keywords or phrases that best describe your gig.',
          style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._tags.map((tag) => Chip(
                  label: Text(tag, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  backgroundColor: AppTheme.primary,
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onDeleted: () {
                    setState(() {
                      _tags.remove(tag);
                    });
                  },
                )),
            if (_tags.length < 5)
              SizedBox(
                width: 200,
                height: 40,
                child: TextField(
                  controller: _tagInputCtrl,
                  style: GoogleFonts.inter(color: context.themeTextDark, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. mobile app',
                    hintStyle: GoogleFonts.inter(color: context.themeTextLight),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    filled: true,
                    fillColor: context.themeSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.black12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.black12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppTheme.primary)),
                  ),
                  onChanged: (val) {
                    if (val.endsWith(',')) {
                      final t = val.replaceAll(',', '').trim().toLowerCase();
                      if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
                        setState(() {
                          _tags.add(t);
                        });
                        _tagInputCtrl.clear();
                      } else if (t.isEmpty || _tags.contains(t) || _tags.length >= 5) {
                        _tagInputCtrl.clear();
                      }
                    }
                  },
                  onSubmitted: (val) {
                    final t = val.replaceAll(',', '').trim().toLowerCase();
                    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
                      setState(() {
                        _tags.add(t);
                      });
                      _tagInputCtrl.clear();
                    }
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.themeTextDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 14, color: context.themeTextDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: context.themeTextLight.withValues(alpha: 0.5)),
            filled: true,
            fillColor: context.themeSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black.withOpacity(0.15))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
            contentPadding: const EdgeInsets.all(16),
            isDense: true,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) && !label.contains('Optional') ? 'Required' : null,
        ),
      ],
    );
  }
}