import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart' as ap;
import '../services/pro_service.dart';
import '../services/verification_service.dart';
import '../theme.dart';
import '../widgets/pro_badge.dart';
import 'admin_orders_view.dart' show adminDate;

/// "Get the blue tick" — identity verification for Reskindev Pro members.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final user = auth.user;
    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: context.themeSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: context.themeTextDark),
        title: Text('Identity verification',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.themeTextDark)),
      ),
      body: user == null || user.isAnonymous
          ? _CenteredMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in first',
              text: 'Sign in to your Reskindev account to get verified.',
              button: 'Sign in',
              onTap: () => context.push('/login'),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: VerificationService.docFor(user.uid).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                final req = snap.data?.exists == true ? VerificationRequest.fromDoc(snap.data!) : null;
                return _VerificationBody(request: req, uid: user.uid);
              },
            ),
    );
  }
}

class _VerificationBody extends StatefulWidget {
  final VerificationRequest? request;
  final String uid;
  const _VerificationBody({required this.request, required this.uid});

  @override
  State<_VerificationBody> createState() => _VerificationBodyState();
}

class _VerificationBodyState extends State<_VerificationBody> {
  /// After a rejection / revoke the form is shown only once they tap "Send again".
  bool _resend = false;

  @override
  void didUpdateWidget(covariant _VerificationBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request?.status != widget.request?.status) _resend = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final req = widget.request;
    final status = auth.isVerified ? 'approved' : (req?.status ?? auth.verificationStatus);

    final children = <Widget>[];
    if (status == 'approved') {
      children.add(_VerifiedCard(request: req));
    } else if (status == 'pending') {
      children.add(_PendingCard(request: req));
    } else if (!auth.isPro) {
      if (status == 'rejected' || status == 'revoked') children.add(_RejectedCard(request: req, status: status!));
      children.add(const _NotProCard());
    } else if ((status == 'rejected' || status == 'revoked') && !_resend) {
      children.add(_RejectedCard(request: req, status: status!, onSendAgain: () => setState(() => _resend = true)));
    } else {
      children.add(const _Intro());
      children.add(_VerificationForm(uid: widget.uid, prefill: req));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── status cards ─────────────────────────

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final List<Widget> extra;
  const _StatusCard({required this.icon, required this.color, required this.title, required this.text, this.extra = const []});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.themeBorder),
        ),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark)),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: context.themeTextLight)),
          ...extra,
        ]),
      );
}

class _VerifiedCard extends StatelessWidget {
  final VerificationRequest? request;
  const _VerifiedCard({this.request});

  @override
  Widget build(BuildContext context) => _StatusCard(
        icon: Icons.verified_rounded,
        color: VerifiedTick.blue,
        title: 'You\'re verified',
        text: 'The blue tick now shows next to your name on your profile, gigs and chats.'
            '${request?.reviewedAt != null ? '\nVerified on ${adminDate(request!.reviewedAt!)}.' : ''}',
      );
}

class _PendingCard extends StatelessWidget {
  final VerificationRequest? request;
  const _PendingCard({this.request});

  @override
  Widget build(BuildContext context) => _StatusCard(
        icon: Icons.hourglass_top_rounded,
        color: AppTheme.warning,
        title: 'Under review',
        text: 'Thanks! The Reskindev team is checking your documents, usually within 1–2 days. '
            'We\'ll let you know as soon as it\'s done.'
            '${request?.submittedAt != null ? '\nSent on ${adminDate(request!.submittedAt!)}.' : ''}',
      );
}

class _RejectedCard extends StatelessWidget {
  final VerificationRequest? request;
  final String status;
  final VoidCallback? onSendAgain;
  const _RejectedCard({this.request, required this.status, this.onSendAgain});

  @override
  Widget build(BuildContext context) {
    final revoked = status == 'revoked';
    final reason = request?.rejectReason ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _StatusCard(
        icon: revoked ? Icons.remove_moderator_outlined : Icons.error_outline_rounded,
        color: AppTheme.error,
        title: revoked ? 'Your blue tick was removed' : 'We couldn\'t verify you',
        text: revoked
            ? 'The Reskindev team removed your verification.'
            : 'Your documents weren\'t approved this time. Please check the reason and send them again.',
        extra: [
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('Reason: $reason',
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextDark)),
            ),
          ],
          if (onSendAgain != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onSendAgain,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Send again', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotProCard extends StatelessWidget {
  const _NotProCard();

  @override
  Widget build(BuildContext context) => _StatusCard(
        icon: Icons.verified_rounded,
        color: VerifiedTick.blue,
        title: 'Get the blue tick',
        text: 'Identity verification is free for Reskindev Pro members. Verified people get a blue tick next to '
            'their name, so buyers and sellers know they\'re real.',
        extra: [
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/pro'),
              icon: const Icon(Icons.bolt_rounded),
              label: Text('Get Reskindev Pro', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ProBadge.amber,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      );
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.verified_rounded, size: 40, color: VerifiedTick.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Get the blue tick',
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: context.themeTextDark)),
              const SizedBox(height: 4),
              Text('Confirm who you are with a photo ID and a selfie. It\'s free with Reskindev Pro.',
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: context.themeTextLight)),
            ]),
          ),
        ]),
      );
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String button;
  final VoidCallback onTap;
  const _CenteredMessage({required this.icon, required this.title, required this.text, required this.button, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: context.themeTextLight),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: context.themeTextDark)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: GoogleFonts.inter(color: context.themeTextLight)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onTap, child: Text(button)),
          ]),
        ),
      );
}

// ───────────────────────── form ─────────────────────────

class _Photo {
  final Uint8List bytes;
  const _Photo(this.bytes);
}

class _VerificationForm extends StatefulWidget {
  final String uid;
  final VerificationRequest? prefill;
  const _VerificationForm({required this.uid, this.prefill});

  @override
  State<_VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends State<_VerificationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _postcode;
  DateTime? _dob;
  String _idType = 'nid';
  String _country = 'Bangladesh';
  _Photo? _front;
  _Photo? _back;
  _Photo? _selfie;
  bool _submitting = false;
  double _progress = 0;
  String _step = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _name = TextEditingController(text: p?.legalName ?? '');
    _address = TextEditingController(text: p?.addressLine ?? '');
    _city = TextEditingController(text: p?.city ?? '');
    _postcode = TextEditingController(text: p?.postcode ?? '');
    if (p != null) {
      _dob = DateTime.tryParse(p.dateOfBirth);
      if (kIdTypeLabels.containsKey(p.idType)) _idType = p.idType;
      if (p.country.isNotEmpty) _country = p.country;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _postcode.dispose();
    super.dispose();
  }

  bool get _needsBack => _idType != 'passport';

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.themeSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CountrySheet(selected: _country),
    );
    if (picked != null) setState(() => _country = picked);
  }

  Future<_Photo?> _pickPhoto({bool selfie = false}) async {
    ImageSource? source = ImageSource.gallery;
    if (!kIsWeb) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: context.themeSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.primary),
                title: Text('Take a photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: c.themeTextDark)),
                onTap: () => Navigator.pop(c, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: Text('Choose from library', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: c.themeTextDark)),
                onTap: () => Navigator.pop(c, ImageSource.gallery),
              ),
            ]),
          ),
        ),
      );
    }
    if (source == null) return null;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length > kVerificationMaxPhotoBytes) {
        _snack('That photo is too big. Please use one under 10 MB.');
        return null;
      }
      return _Photo(bytes);
    } catch (e) {
      _snack('Could not open the ${source == ImageSource.camera ? 'camera' : 'photo library'}. '
          'Check that Reskindev is allowed to use it in Settings.');
      return null;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      setState(() => _error = 'Please add your date of birth.');
      return;
    }
    if (_front == null || (_needsBack && _back == null) || _selfie == null) {
      setState(() => _error = 'Please add all the photos.');
      return;
    }
    FocusScope.of(context).unfocus();

    final uploads = <(String, _Photo)>[
      ('id_front', _front!),
      if (_needsBack) ('id_back', _back!),
      ('selfie', _selfie!),
    ];
    setState(() {
      _submitting = true;
      _progress = 0;
      _step = 'Uploading photos…';
    });
    try {
      final paths = <String, String>{};
      for (var i = 0; i < uploads.length; i++) {
        final (kind, photo) = uploads[i];
        paths[kind] = await VerificationService.uploadPhoto(
          uid: widget.uid,
          kind: kind,
          bytes: photo.bytes,
          onProgress: (p) {
            if (mounted) setState(() => _progress = (i + p) / uploads.length * 0.9);
          },
        );
      }
      if (mounted) {
        setState(() {
          _progress = 0.95;
          _step = 'Sending to Reskindev…';
        });
      }
      await VerificationService.submit(
        legalName: _name.text.trim(),
        dateOfBirth: _fmt(_dob!),
        idType: _idType,
        country: _country,
        addressLine: _address.text.trim(),
        city: _city.text.trim(),
        postcode: _postcode.text.trim(),
        idFront: paths['id_front']!,
        idBack: paths['id_back'],
        selfie: paths['selfie']!,
      );
      _snack('Sent! We\'ll review it within 1–2 days.');
      // The verifications/{uid} stream switches this screen to "Under review".
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().contains('firebase_storage') || e.toString().contains('storage/')
            ? 'Could not upload the photos. Check your connection and try again.'
            : proErrorMessage(e));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: context.themeTextLight),
        filled: true,
        fillColor: context.themeSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.6)),
      );

  String? _required(String? v, String what) => (v == null || v.trim().isEmpty) ? 'Please enter your $what' : null;

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: context.themeTextLight)),
      );

  Widget _pickerField({required String label, required String value, required IconData icon, required VoidCallback onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _submitting ? null : onTap,
        child: InputDecorator(
          decoration: _dec(label).copyWith(suffixIcon: Icon(icon, color: context.themeTextLight)),
          child: Text(value, style: GoogleFonts.inter(fontSize: 15, color: context.themeTextDark)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = GoogleFonts.inter(fontSize: 15, color: context.themeTextDark);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('About you'),
          TextFormField(
            controller: _name,
            enabled: !_submitting,
            style: text,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Full legal name', hint: 'Exactly as on your ID'),
            validator: (v) => _required(v, 'full name'),
          ),
          const SizedBox(height: 12),
          _pickerField(
            label: 'Date of birth',
            value: _dob == null ? 'Choose a date' : adminDate(_dob!),
            icon: Icons.calendar_today_outlined,
            onTap: _pickDob,
          ),
          const SizedBox(height: 12),
          _pickerField(label: 'Country', value: _country, icon: Icons.expand_more_rounded, onTap: _pickCountry),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            enabled: !_submitting,
            style: text,
            decoration: _dec('Address', hint: 'House, road, area'),
            validator: (v) => _required(v, 'address'),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _city,
                enabled: !_submitting,
                style: text,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('City'),
                validator: (v) => _required(v, 'city'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _postcode,
                enabled: !_submitting,
                style: text,
                decoration: _dec('Postcode'),
                validator: (v) => _required(v, 'postcode'),
              ),
            ),
          ]),
          _section('Your ID'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kIdTypeLabels.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _idType == e.key,
                onSelected: _submitting ? null : (_) => setState(() => _idType = e.key),
                selectedColor: AppTheme.primary.withValues(alpha: 0.18),
                backgroundColor: context.themeSurface,
                side: BorderSide(color: _idType == e.key ? AppTheme.primary : context.themeBorder),
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: _idType == e.key ? AppTheme.primary : context.themeTextDark,
                ),
                showCheckmark: false,
              ),
          ]),
          const SizedBox(height: 14),
          _PhotoTile(
            title: _idType == 'passport' ? 'Passport photo page' : 'Front of your ID',
            hint: 'Flat, in good light, all four corners visible and the text easy to read.',
            icon: Icons.badge_outlined,
            photo: _front,
            enabled: !_submitting,
            onPick: () async {
              final p = await _pickPhoto();
              if (p != null) setState(() => _front = p);
            },
          ),
          if (_needsBack)
            _PhotoTile(
              title: 'Back of your ID',
              hint: 'Turn the card over and take the same kind of photo.',
              icon: Icons.flip_outlined,
              photo: _back,
              enabled: !_submitting,
              onPick: () async {
                final p = await _pickPhoto();
                if (p != null) setState(() => _back = p);
              },
            ),
          _PhotoTile(
            title: 'Selfie holding your ID',
            hint: 'Hold the ID next to your face. Both your face and the ID should be clear.',
            icon: Icons.face_retouching_natural_outlined,
            photo: _selfie,
            enabled: !_submitting,
            onPick: () async {
              final p = await _pickPhoto(selfie: true);
              if (p != null) setState(() => _selfie = p);
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Only the Reskindev team sees these photos. They\'re used only to confirm your identity.',
                  style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: context.themeTextDark),
                ),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.error)),
          ],
          const SizedBox(height: 18),
          if (_submitting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                color: AppTheme.primary,
                backgroundColor: context.themeBorder,
              ),
            ),
            const SizedBox(height: 8),
            Text(_step, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: context.themeTextLight)),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : Text('Send for review', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final _Photo? photo;
  final bool enabled;
  final VoidCallback onPick;
  const _PhotoTile({
    required this.title,
    required this.hint,
    required this.icon,
    required this.photo,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final has = photo != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.themeSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPick : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: has ? AppTheme.success.withValues(alpha: 0.6) : context.themeBorder),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: has
                      ? Image.memory(photo!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
                      : Container(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          child: Icon(icon, size: 32, color: AppTheme.primary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(title,
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.themeTextDark)),
                    ),
                    if (has) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(hint, style: GoogleFonts.inter(fontSize: 12.5, height: 1.35, color: context.themeTextLight)),
                  const SizedBox(height: 6),
                  Text(has ? 'Retake' : 'Add photo',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  final String selected;
  const _CountrySheet({required this.selected});

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty ? kCountries : kCountries.where((c) => c.toLowerCase().contains(q)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: context.themeBorder, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            style: GoogleFonts.inter(color: context.themeTextDark),
            decoration: InputDecoration(
              hintText: 'Search country',
              prefixIcon: Icon(Icons.search_rounded, color: context.themeTextLight),
              filled: true,
              fillColor: context.themeCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.themeBorder)),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No country found', style: GoogleFonts.inter(color: context.themeTextLight)))
              : ListView.builder(
                  controller: scroll,
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final sel = c == widget.selected;
                    return ListTile(
                      title: Text(c,
                          style: GoogleFonts.inter(
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? AppTheme.primary : context.themeTextDark)),
                      trailing: sel ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null,
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
