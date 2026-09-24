import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/page_model.dart';

class PageProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<PageModel> _pages = [];
  bool _loading = true;

  List<PageModel> get pages => _pages;
  List<PageModel> get visiblePages {
    final seen = <String>{};
    final list = <PageModel>[];
    for (final p in _pages.where((p) => p.isVisible)) {
      final key = p.title.trim().toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        list.add(p);
      }
    }
    return list;
  }
  bool get loading => _loading;

  PageProvider() {
    _listenToPages();
  }

  void _listenToPages() {
    _firestore.collection('pages').orderBy('order').snapshots().listen((snapshot) {
      _pages = snapshot.docs.map((doc) => PageModel.fromFirestore(doc)).toList();
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('Error fetching pages: $e');
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> addPage(PageModel page) async {
    try {
      await _firestore.collection('pages').add(page.toMap());
    } catch (e) {
      if (kDebugMode) print('Error adding page: $e');
      rethrow;
    }
  }

  Future<void> updatePage(PageModel page) async {
    try {
      await _firestore.collection('pages').doc(page.id).update(page.toMap());
    } catch (e) {
      if (kDebugMode) print('Error updating page: $e');
      rethrow;
    }
  }

  Future<void> deletePage(String id) async {
    try {
      await _firestore.collection('pages').doc(id).delete();
    } catch (e) {
      if (kDebugMode) print('Error deleting page: $e');
      rethrow;
    }
  }
}
