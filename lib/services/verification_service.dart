import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'pro_service.dart';

/// Identity verification (blue tick) for Reskindev Pro members + priority support helpers.
///
/// Photos go to private Storage paths verification/{uid}/..., the callable submitVerification
/// creates verifications/{uid}, and admins decide with reviewVerification. Clients never write
/// verifications/{uid} or users.verified themselves.

/// Max photo size accepted by Storage rules.
const int kVerificationMaxPhotoBytes = 10 * 1024 * 1024;

const Map<String, String> kIdTypeLabels = {
  'nid': 'National ID',
  'passport': 'Passport',
  'driving_license': 'Driving licence',
};

String idTypeLabel(String? t) => kIdTypeLabels[t] ?? (t ?? '');

DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _s(dynamic v) => v == null ? '' : v.toString().trim();

/// One verifications/{uid} document.
class VerificationRequest {
  final String uid;
  final String name;
  final String email;
  /// pending | approved | rejected | revoked
  final String status;
  final String legalName;
  final String dateOfBirth;
  final String idType;
  final String country;
  final String addressLine;
  final String city;
  final String postcode;
  final String idFront;
  final String idBack;
  final String selfie;
  final bool isPro;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String reviewedByName;
  final String rejectReason;
  final List<Map<String, dynamic>> history;

  VerificationRequest.fromMap(String id, Map<String, dynamic> d)
      : uid = _s(d['uid']).isNotEmpty ? _s(d['uid']) : id,
        name = _s(d['name']),
        email = _s(d['email']),
        status = _s(d['status']).isEmpty ? 'pending' : _s(d['status']),
        legalName = _s(d['legalName']),
        dateOfBirth = _s(d['dateOfBirth']),
        idType = _s(d['idType']),
        country = _s(d['country']),
        addressLine = _s((d['address'] as Map?)?['line1']),
        city = _s((d['address'] as Map?)?['city']),
        postcode = _s((d['address'] as Map?)?['postcode']),
        idFront = _s((d['files'] as Map?)?['idFront']),
        idBack = _s((d['files'] as Map?)?['idBack']),
        selfie = _s((d['files'] as Map?)?['selfie']),
        isPro = d['isPro'] == true,
        submittedAt = _date(d['submittedAt']),
        reviewedAt = _date(d['reviewedAt']),
        reviewedByName = _s(d['reviewedByName']),
        rejectReason = _s(d['rejectReason']),
        history = [
          for (final h in (d['history'] is List ? d['history'] as List : const []))
            if (h is Map) Map<String, dynamic>.from(h),
        ];

  factory VerificationRequest.fromDoc(DocumentSnapshot doc) =>
      VerificationRequest.fromMap(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});

  String get displayName => name.isNotEmpty ? name : (legalName.isNotEmpty ? legalName : 'Unnamed user');
  String get address => [addressLine, city, postcode].where((s) => s.isNotEmpty).join(', ');
}

class VerificationService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> docFor(String uid) => _db.collection('verifications').doc(uid);

  /// Uploads one JPEG to `verification/{uid}/{kind}_<timestamp>.jpg` and returns the Storage path.
  /// [kind] is id_front, id_back or selfie. [onProgress] gets 0..1.
  static Future<String> uploadPhoto({
    required String uid,
    required String kind,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'verification/$uid/${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final task = FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    onProgress?.call(1);
    return path;
  }

  /// Calls submitVerification. Returns the new status ("pending").
  static Future<String> submit({
    required String legalName,
    required String dateOfBirth,
    required String idType,
    required String country,
    required String addressLine,
    required String city,
    required String postcode,
    required String idFront,
    String? idBack,
    required String selfie,
  }) async {
    final res = await proFunctions.httpsCallable('submitVerification').call({
      'legalName': legalName,
      'dateOfBirth': dateOfBirth,
      'idType': idType,
      'country': country,
      'address': {'line1': addressLine, 'city': city, 'postcode': postcode},
      'files': {
        'idFront': idFront,
        if (idBack != null && idBack.isNotEmpty) 'idBack': idBack,
        'selfie': selfie,
      },
    });
    final data = res.data;
    return data is Map && data['status'] != null ? data['status'].toString() : 'pending';
  }

  /// Admin: [decision] is approve | reject | revoke. A reason (5+ chars) is required for reject.
  static Future<String> review(String uid, String decision, {String? reason}) async {
    final res = await proFunctions.httpsCallable('reviewVerification').call({
      'uid': uid,
      'decision': decision,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    final data = res.data;
    return data is Map && data['status'] != null ? data['status'].toString() : decision;
  }

  /// Admin: put a support ticket at the front of the line (or take it off).
  static Future<void> setTicketPriority(String ticketId, bool priority) =>
      proFunctions.httpsCallable('setTicketPriority').call({'ticketId': ticketId, 'priority': priority});
}

/// Countries for the verification form (searchable sheet). Bangladesh is the default.
const List<String> kCountries = [
  'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Antigua and Barbuda', 'Argentina', 'Armenia',
  'Australia', 'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium',
  'Belize', 'Benin', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei', 'Bulgaria',
  'Burkina Faso', 'Burundi', 'Cabo Verde', 'Cambodia', 'Cameroon', 'Canada', 'Central African Republic', 'Chad',
  'Chile', 'China', 'Colombia', 'Comoros', 'Congo', 'Costa Rica', "Côte d'Ivoire", 'Croatia', 'Cuba', 'Cyprus',
  'Czechia', 'Democratic Republic of the Congo', 'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic',
  'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia', 'Fiji',
  'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana', 'Greece', 'Grenada', 'Guatemala',
  'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras', 'Hong Kong', 'Hungary', 'Iceland', 'India',
  'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan', 'Kenya',
  'Kiribati', 'Kosovo', 'Kuwait', 'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya',
  'Liechtenstein', 'Lithuania', 'Luxembourg', 'Macao', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali',
  'Malta', 'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco',
  'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal', 'Netherlands',
  'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'North Korea', 'North Macedonia', 'Norway', 'Oman',
  'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Poland',
  'Portugal', 'Puerto Rico', 'Qatar', 'Romania', 'Russia', 'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia',
  'Saint Vincent and the Grenadines', 'Samoa', 'San Marino', 'Sao Tome and Principe', 'Saudi Arabia',
  'Senegal', 'Serbia', 'Seychelles', 'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands',
  'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden',
  'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand', 'Timor-Leste', 'Togo', 'Tonga',
  'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine',
  'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City',
  'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
];
