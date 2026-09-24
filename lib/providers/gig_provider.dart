import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gig_model.dart';
import 'auth_provider.dart';

class GigProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  List<GigModel> _gigs = [];
  List<String> _categories = [];
  bool _loading = true;
  AuthProvider? _auth;

  List<GigModel> get gigs {
    if (_auth?.isAdmin == true) return _gigs;
    // Support both 'active' (Web schema) and 'published' (legacy) statuses
    return _gigs.where((g) => g.status == 'active' || g.status == 'published').toList();
  }

  List<String> get categories => _categories;

  bool get loading => _loading;

  GigProvider({AuthProvider? auth}) : _auth = auth {
    _listen();
    _listenCategories();
  }

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    notifyListeners();
  }


  Future<void> refresh() async {
    // Firestore realtime listener keeps data updated, but this gives UI feedback
    await Future.delayed(const Duration(milliseconds: 800));
    notifyListeners();
  }

  GigModel? getById(String id) {
    try {
      return _gigs.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  void _listen() {
    _db.collection('services').snapshots().listen((snap) async {
      final docs = snap.docs.map((d) => GigModel.fromFirestore(d)).toList();
      docs.sort((a, b) => a.order.compareTo(b.order)); 
      _gigs = docs;
      _loading = false;
      notifyListeners();

      // Dynamic Fallback: Check for missing ratings and calculate dynamically
      for (var gig in docs) {
        if (gig.averageRating == 0.0 && gig.reviewCount == 0) {
          try {
            final revSnap = await _db.collection('services').doc(gig.id).collection('reviews').get();
            if (revSnap.docs.isNotEmpty) {
              double total = 0;
              for (var r in revSnap.docs) {
                total += (r.data()['rating'] as num?)?.toDouble() ?? 5.0;
              }
              final avg = double.parse((total / revSnap.docs.length).toStringAsFixed(1));
              
              // Update firestore, which will trigger another snapshot event to update UI
              await _db.collection('services').doc(gig.id).update({
                'rating': avg,
                'averageRating': avg,
                'reviewCount': revSnap.docs.length,
              });
            }
          } catch (e) {
            debugPrint("Fallback rating calculation failed for ${gig.id}: $e");
          }
        }
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error loading gigs: $e');
      _loading = false;
      notifyListeners();
    });
  }

  void _listenCategories() {
    _db.collection('admin_settings').doc('categories').snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data();
        if (data != null && data.containsKey('list')) {
          _categories = List<String>.from(data['list'] ?? []);
        } else {
          _categories = [];
        }
      } else {
        _categories = [];
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error loading categories: $e');
    });
  }

  Future<void> updateServiceOrder(List<GigModel> reorderedGigs) async {
    _gigs = reorderedGigs;
    notifyListeners();

    final batch = _db.batch();
    for (int i = 0; i < reorderedGigs.length; i++) {
      batch.update(_db.collection('services').doc(reorderedGigs[i].id), {'order': i});
    }
    await batch.commit();
  }
}
