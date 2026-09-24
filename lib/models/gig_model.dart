import 'package:cloud_firestore/cloud_firestore.dart';

class GigModel {
  final String id;
  final String title;
  final String slug;
  final String category;
  final String description; // supports plain text or HTML
  final String imageUrl;    // legacy single image (kept for backward compatibility)
  final List<String> images; // Web schema: array of image URLs
  final String? youtubeUrl;
  final String? whatsappNumber;
  final List<String> galleryImages;
  final List<String> masterFeatures;
  final List<GigPackage> packages;
  final double deliveryCost;
  final double galleryUnlockPrice;
  final Map<String, double> galleryCoupons;
  final int order;
  final String status; // 'active', 'published', 'pending', 'draft'
  final String authorId;   // UID of the freelancer
  final String authorName;
  final List<String> keywords; // Search keywords/tags
  final bool isVacation;
      
  // Ratings
  final int reviewCount;
  final double averageRating;
 // Name of the freelancer

  GigModel({
    required this.id,
    required this.title,
    this.slug = '',
    this.category = '',
    required this.description,
    this.imageUrl = '',
    this.images = const [],
    this.youtubeUrl,
    this.whatsappNumber,
    this.galleryImages = const [],
    this.masterFeatures = const [],
    required this.packages,
    this.deliveryCost = 0,
    this.galleryUnlockPrice = 0,
    this.galleryCoupons = const {},
    this.order = 0,
    this.status = 'active',
    this.authorId = '',
    this.authorName = '',
    this.keywords = const [],
    this.isVacation = false,
    this.reviewCount = 0,
    this.averageRating = 0.0,
  });

  factory GigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // images: support both 'images' (Web schema) and 'imageUrl' (legacy)
    final imagesList = List<String>.from(data['images'] ?? []);
    final legacyImageUrl = data['imageUrl'] as String? ?? '';

    return GigModel(
      id: doc.id,
      averageRating: (data['rating'] as num?)?.toDouble() ?? (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? (data['reviews'] as num?)?.toInt() ?? 0,
      title: data['title'] ?? '',
      slug: data['slug'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? data['tags'] ?? []),
      imageUrl: legacyImageUrl.isNotEmpty
          ? legacyImageUrl
          : (imagesList.isNotEmpty ? imagesList.first : ''),
      images: imagesList.isNotEmpty
          ? imagesList
          : (legacyImageUrl.isNotEmpty ? [legacyImageUrl] : []),
      youtubeUrl: data['youtubeUrl'],
      whatsappNumber: data['whatsappNumber'],
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
      masterFeatures: List<String>.from(data['masterFeatures'] ?? []),
      deliveryCost: (data['deliveryCost'] as num?)?.toDouble() ?? 0,
      galleryUnlockPrice: (data['galleryUnlockPrice'] as num?)?.toDouble() ?? 0,
      galleryCoupons: () {
        final raw = data['galleryCoupons'];
        if (raw is Map<String, dynamic>) {
          return raw.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
        return <String, double>{};
      }(),
      order: (data['order'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'active',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      isVacation: data['isVacation'] ?? false,
      packages: (data['packages'] as List<dynamic>? ?? [])
          .map((p) => GigPackage.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'slug': slug.isNotEmpty ? slug : _generateSlug(title),
      'category': category,
      'description': description,
      'keywords': keywords,
      'tags': keywords, // keep tags for backward compatibility
      'imageUrl': imageUrl,
      'images': images.isNotEmpty ? images : (imageUrl.isNotEmpty ? [imageUrl] : []),
      'galleryImages': galleryImages,
      'masterFeatures': masterFeatures,
      'deliveryCost': deliveryCost,
      'galleryUnlockPrice': galleryUnlockPrice,
      'galleryCoupons': galleryCoupons,
      'order': order,
      'status': status,
      'authorId': authorId,
      'authorName': authorName,
      'isVacation': isVacation,
      'reviewCount': reviewCount,
      'averageRating': averageRating,
      'packages': packages.map((p) => p.toMap()).toList(),
    };
    // Only include optional fields if non-null
    if (youtubeUrl != null) map['youtubeUrl'] = youtubeUrl;
    if (whatsappNumber != null) map['whatsappNumber'] = whatsappNumber;
    return map;
  }

  static String _generateSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
  }

  double get basePrice => packages.isNotEmpty ? packages.first.price : 0;

  /// Check if the gig is visible to public (active or published)
  bool get isVisible => (status == 'active' || status == 'published') && !isVacation;
}

class GigPackage {
  final String id;   // 'basic', 'standard', 'premium'
  final String name;
  final double price;
  final String description;
  final int deliveryDays;
  final List<String> features;     // Legacy support
  final List<bool> featureChecks;  // Maps 1:1 with masterFeatures in GigModel

  GigPackage({
    this.id = '',
    required this.name,
    required this.price,
    required this.description,
    required this.deliveryDays,
    this.features = const [],
    this.featureChecks = const [],
  });

  factory GigPackage.fromMap(Map<String, dynamic> map) {
    return GigPackage(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Basic',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      description: map['description'] ?? '',
      deliveryDays: (map['deliveryDays'] as num?)?.toInt() ?? 3,
      features: List<String>.from(map['features'] ?? []),
      featureChecks: List<bool>.from(map['featureChecks'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    'price': price,
    'description': description,
    'deliveryDays': deliveryDays,
    'features': features,
    'featureChecks': featureChecks,
  };
}
