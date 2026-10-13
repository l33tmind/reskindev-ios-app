import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Reskindev Pro product ids (same on the App Store and Google Play).
const String kProMonthlyId = 'reskindev.pro.monthly';
const String kProYearlyId = 'reskindev.pro.yearly';
const Set<String> kProProductIds = {kProMonthlyId, kProYearlyId};

/// Fallback prices shown when the store products can't be loaded.
const String kProMonthlyFallbackPrice = '\$7.99';
const String kProYearlyFallbackPrice = '\$79.99';

/// The Cloud Functions region every Pro callable lives in.
FirebaseFunctions get proFunctions => FirebaseFunctions.instanceFor(region: 'asia-south1');

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// The `pro` map of a users/{uid} document, or null.
Map<String, dynamic>? proOf(Map<String, dynamic>? userData) {
  final p = userData?['pro'];
  return p is Map ? Map<String, dynamic>.from(p) : null;
}

/// When this person's Pro ends (null when they've never had it).
DateTime? proExpiresAt(Map<String, dynamic>? userData) => _toDate(proOf(userData)?['expiresAt']);

/// pro.active == true && pro.expiresAt > now — always check the date too.
bool isPro(Map<String, dynamic>? userData) {
  final pro = proOf(userData);
  if (pro == null || pro['active'] != true) return false;
  final exp = _toDate(pro['expiresAt']);
  return exp != null && exp.isAfter(DateTime.now());
}

/// A friendly message out of a callable error (the functions send HttpsError with a readable message).
String proErrorMessage(Object e) {
  if (e is FirebaseFunctionsException) {
    final m = e.message?.trim() ?? '';
    if (m.isNotEmpty && m.toUpperCase() != e.code.toUpperCase() && m.toLowerCase() != 'internal') return m;
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in first.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Could not reach Reskindev. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Store purchases for Reskindev Pro (App Store + Google Play subscriptions).
///
/// Every purchase/restore is sent to the backend (verifyAppleSubscription / verifyGoogleSubscription),
/// which writes users/{uid}.pro. The app then reads Pro status from the users doc (see AuthProvider.isPro).
class ProService extends ChangeNotifier {
  ProService() {
    if (!storeSupported) return;
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('Pro purchaseStream error: $e'),
    );
    // Quietly re-check the store once per sign-in, so renewals reach the backend.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _restoredForUid = null;
        return;
      }
      if (_restoredForUid == user.uid || user.isAnonymous) return;
      _restoredForUid = user.uid;
      unawaited(restorePurchases(quiet: true));
    });
    unawaited(loadProducts());
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<User?>? _authSub;
  String? _restoredForUid;

  /// In-app purchases only exist on the iOS and Android apps.
  static bool get storeSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  static bool get isApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  bool _loadingProducts = false;
  bool get loadingProducts => _loadingProducts;

  final Map<String, ProductDetails> _products = {};
  ProductDetails? get monthly => _products[kProMonthlyId];
  ProductDetails? get yearly => _products[kProYearlyId];
  bool get productsLoaded => monthly != null || yearly != null;

  bool _busy = false;
  /// A purchase / restore / verification is running.
  bool get busy => _busy;

  bool _quiet = false;

  String? _error;
  String? get error => _error;

  String? _info;
  /// A neutral message (e.g. "No purchases to restore").
  String? get info => _info;

  bool _justActivated = false;
  /// True right after a purchase was verified — the Pro page shows a celebration.
  bool get justActivated => _justActivated;

  void clearMessages() {
    _error = null;
    _info = null;
    _justActivated = false;
    notifyListeners();
  }

  String priceFor(String productId) {
    final p = _products[productId];
    if (p != null) return p.price;
    return productId == kProYearlyId ? kProYearlyFallbackPrice : kProMonthlyFallbackPrice;
  }

  Future<void> loadProducts() async {
    if (!storeSupported || _loadingProducts) return;
    _loadingProducts = true;
    notifyListeners();
    try {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        final res = await _iap.queryProductDetails(kProProductIds);
        if (res.error != null) debugPrint('Pro products error: ${res.error}');
        if (res.notFoundIDs.isNotEmpty) debugPrint('Pro products not found: ${res.notFoundIDs}');
        // Google Play can list one entry per base plan / offer; keep the first of each id.
        for (final p in res.productDetails) {
          _products.putIfAbsent(p.id, () => p);
        }
      }
    } catch (e) {
      debugPrint('Pro loadProducts failed: $e');
    }
    _loadingProducts = false;
    notifyListeners();
  }

  /// Start the store purchase sheet for [productId]. The result arrives on the purchase stream.
  Future<void> buy(String productId) async {
    _error = null;
    _info = null;
    _justActivated = false;
    if (FirebaseAuth.instance.currentUser == null) {
      _error = 'Please sign in first.';
      notifyListeners();
      return;
    }
    if (!storeSupported) {
      _error = 'Subscriptions are available in the Reskindev iOS and Android apps.';
      notifyListeners();
      return;
    }
    if (!productsLoaded) await loadProducts();
    final product = _products[productId];
    if (product == null) {
      _error = _storeAvailable
          ? 'This plan isn\'t available in the store right now. Please try again later.'
          : 'The store isn\'t available on this device right now.';
      notifyListeners();
      return;
    }
    _quiet = false;
    _busy = true;
    notifyListeners();
    try {
      // Subscriptions are bought as non-consumables in in_app_purchase.
      final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) {
        _busy = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Pro buy failed: $e');
      _busy = false;
      _error = 'Could not start the purchase. Please try again.';
      notifyListeners();
    }
  }

  /// Ask the store for active subscriptions; each one is re-verified by the backend.
  /// [quiet] = no spinner and no messages (used once on app start).
  Future<void> restorePurchases({bool quiet = false}) async {
    if (!storeSupported || FirebaseAuth.instance.currentUser == null) return;
    _quiet = quiet;
    if (!quiet) {
      _error = null;
      _info = null;
      _busy = true;
      notifyListeners();
    }
    _restoredSomething = false;
    try {
      if (!await _iap.isAvailable()) {
        if (!quiet) _error = 'The store isn\'t available on this device right now.';
      } else {
        await _iap.restorePurchases();
        // Restored items arrive on the purchase stream; give them a moment before saying "nothing found".
        if (!quiet) {
          await Future<void>.delayed(const Duration(seconds: 4));
          if (!_restoredSomething && _error == null) {
            _info = 'No active Reskindev Pro subscription found for this ${isApple ? 'Apple ID' : 'Google account'}.';
          }
        }
      }
    } catch (e) {
      debugPrint('Pro restore failed: $e');
      if (!quiet) _error = 'Could not restore purchases. Please try again.';
    }
    if (!quiet) {
      _busy = false;
      notifyListeners();
    }
  }

  bool _restoredSomething = false;

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!kProProductIds.contains(p.productID)) {
        if (p.pendingCompletePurchase) await _complete(p);
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.pending:
          if (!_quiet) {
            _busy = true;
            notifyListeners();
          }
          break;
        case PurchaseStatus.canceled:
          _busy = false;
          if (p.pendingCompletePurchase) await _complete(p);
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _busy = false;
          if (!_quiet) _error = p.error?.message.isNotEmpty == true ? p.error!.message : 'The purchase didn\'t go through.';
          if (p.pendingCompletePurchase) await _complete(p);
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _restoredSomething = true;
          await _verify(p, fromPurchase: p.status == PurchaseStatus.purchased);
          break;
      }
    }
  }

  Future<void> _verify(PurchaseDetails p, {required bool fromPurchase}) async {
    if (FirebaseAuth.instance.currentUser == null) return; // verify after sign-in (store re-delivers)
    final showUi = !_quiet || fromPurchase;
    if (showUi) {
      _busy = true;
      notifyListeners();
    }
    try {
      // StoreKit 2 (default in in_app_purchase_storekit 0.4+): serverVerificationData is the transaction's JWS.
      // Google Play: serverVerificationData is the purchase token.
      final token = p.verificationData.serverVerificationData;
      if (isApple) {
        await proFunctions.httpsCallable('verifyAppleSubscription').call({'signedTransaction': token});
      } else {
        await proFunctions
            .httpsCallable('verifyGoogleSubscription')
            .call({'purchaseToken': token, 'productId': p.productID});
      }
      // Only finish the transaction once the backend has it, so a failed check is retried by the store.
      if (p.pendingCompletePurchase) await _complete(p);
      if (showUi) {
        _justActivated = fromPurchase;
        if (!fromPurchase) _info = 'Your Reskindev Pro subscription was restored.';
      }
    } catch (e) {
      debugPrint('Pro verify failed: $e');
      if (showUi) _error = proErrorMessage(e);
    }
    if (showUi) _busy = false;
    notifyListeners();
  }

  Future<void> _complete(PurchaseDetails p) async {
    try {
      await _iap.completePurchase(p);
    } catch (e) {
      debugPrint('Pro completePurchase failed: $e');
    }
  }

  // ── Admin ──────────────────────────────────────────────

  /// Give [uid] Pro for [days] days (admin only).
  static Future<void> adminGivePro(String uid, int days) =>
      proFunctions.httpsCallable('adminSetPro').call({'uid': uid, 'days': days});

  /// Remove Pro from [uid] (admin only).
  static Future<void> adminRemovePro(String uid) =>
      proFunctions.httpsCallable('adminSetPro').call({'uid': uid, 'revoke': true});

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
