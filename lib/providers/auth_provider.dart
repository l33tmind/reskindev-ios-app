import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../main.dart';
import '../models/order_model.dart';

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? _currentUser;
  User? get user => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isGuest => _currentUser?.isAnonymous ?? false;
  List<String> _blockedUsers = [];
  List<String> get blockedUsers => _blockedUsers;
  bool get isAdmin => _currentUser?.email?.toLowerCase() == 'mdrobiussany1225@gmail.com';

  bool _isSellerMode = false;
  bool get isSellerMode => _isSellerMode;

  void toggleSellerMode(bool val) {
    _isSellerMode = val;
    notifyListeners();
  }


  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Listen to Firebase auth state — auto-refreshes all screens on sign-in/out
    _auth.authStateChanges().listen((firebaseUser) async {
      _currentUser = firebaseUser;
      if (firebaseUser != null) {
        await loadProfile();
        await _updateFcmToken();
        if (isAdmin) {
          _startAdminOrderListener();
        } else {
          _stopAdminOrderListener();
        }
      } else {
        _phone = null;
        _company = null;
        _address = null;
        _photoUrl = null;
        _username = null;
        _blockedUsers.clear();
        _profileLoaded = false;
        _stopAdminOrderListener();
      }
      notifyListeners();
    });
  }

  StreamSubscription? _orderSubscription;

  void _startAdminOrderListener() {
    _stopAdminOrderListener(); // Ensure no double listeners
    bool isInitial = true;
    _orderSubscription = _db.collection('orders').snapshots().listen((snapshot) {
      if (isInitial) {
        isInitial = false;
        return;
      }
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final order = OrderModel.fromFirestore(change.doc);
          _showLocalNotification(order);
        }
      }
    });
  }

  void _stopAdminOrderListener() {
    _orderSubscription?.cancel();
    _orderSubscription = null;
  }

  DateTime? _lastAdminNotificationTime;

  Future<void> _showLocalNotification(OrderModel order) async {
    final now = DateTime.now();
    if (_lastAdminNotificationTime != null && now.difference(_lastAdminNotificationTime!).inSeconds < 2) {
      return; // Rate limit to prevent spam
    }
    _lastAdminNotificationTime = now;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      order.id.hashCode,
      'New Order Received! 🚀',
      '${order.clientName} ordered ${order.gigTitle} for \$${order.price.toStringAsFixed(0)}',
      platformChannelSpecifics,
      payload: '/admin',
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAdminOrderListener();
    super.dispose();
  }

  Future<void> _updateFcmToken() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(u.uid).update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Extended profile data loaded from Firestore
  String? _phone;
  String? _company;
  String? _address;
  String? _photoUrl;
  String? _username;
  String? _role;
  double _averageRating = 0.0;
  int _reviewCount = 0; // 'admin', 'freelancer', 'buyer'
  bool _profileLoaded = false;
  double _walletBalance = 0.0;
  double _availableToWithdraw = 0.0;
  Timer? _heartbeatTimer;

  String get displayName => user?.displayName ?? '';
  String get email => user?.email ?? '';
  String get photoUrl => _photoUrl ?? user?.photoURL ?? '';
  String? get phone => _phone;
  String? get company => _company;
  String? get address => _address;
  String? get username => _username;
  String? get role => _role;
  double get averageRating => _averageRating;
  int get reviewCount => _reviewCount;
  bool get profileLoaded => _profileLoaded;
  double get walletBalance => _walletBalance;
  double get availableToWithdraw => _availableToWithdraw;
  bool get isFreelancer => _role == 'freelancer' || _role == 'admin' || isAdmin;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: '652374646493-9lu1tt5u5ssmtmeedqralfpa0ulttcjh.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        await _auth.signInWithCredential(credential);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: '652374646493-9lu1tt5u5ssmtmeedqralfpa0ulttcjh.apps.googleusercontent.com',
          clientId: !kIsWeb && Platform.isIOS ? '652374646493-kbhqc8o82h70378uatdk498mv1ulqae4.apps.googleusercontent.com' : null,
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return; 
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
      
      try {
        await _saveUserToFirestore();
        await loadProfile();
      } catch (dbErr) {
        debugPrint("Firestore save/load error on signin: $dbErr");
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      final AuthorizationCredentialAppleID appleIdCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleIdCredential.identityToken,
        accessToken: appleIdCredential.authorizationCode,
      );

      await _auth.signInWithCredential(credential);

      try {
        await _saveUserToFirestore();
        await loadProfile();
      } catch (dbErr) {
        debugPrint("Firestore save/load error on signin: $dbErr");
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      await loadProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Email Sign-In error: $e');
      rethrow;
    }
  }

  Future<void> registerWithEmail(String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name);
      await _saveUserToFirestore();
      await loadProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Email Registration error: $e');
      rethrow;
    }
  }

  /// Guest login: a Firebase anonymous account named "Guest 1234", so the guest
  /// can order, sell and chat without an email or password.
  Future<void> signInAsGuest() async {
    try {
      final cred = await _auth.signInAnonymously();
      final u = cred.user;
      if (u != null && (u.displayName ?? '').isEmpty) {
        final tag = (1000 + math.Random().nextInt(9000)).toString();
        await u.updateDisplayName('Guest $tag');
        await u.reload();
        _currentUser = _auth.currentUser;
      }
      await _saveUserToFirestore();
      await loadProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('Guest Sign-In error: $e');
      rethrow;
    }
  }

  /// Pick a photo from the gallery and make it the profile picture everywhere (chat, inbox, orders, website).
  /// Returns false when the person cancelled.
  Future<bool> pickAndUploadProfilePhoto({VoidCallback? onUploading}) async {
    final u = _auth.currentUser;
    if (u == null) return false;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null) return false;
    onUploading?.call();
    final bytes = await picked.readAsBytes();
    // One file per person, replaced on every change, so old photos don't pile up
    final ref = FirebaseStorage.instance.ref('profile_pictures/${u.uid}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    // A new query string makes every phone fetch the new picture instead of the cached old one
    final url = '${await ref.getDownloadURL()}&v=${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('users').doc(u.uid).set({'photoUrl': url}, SetOptions(merge: true));
    await u.updatePhotoURL(url);
    _photoUrl = url;
    notifyListeners();
    return true;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      debugPrint('Password Reset error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _phone = null;
    _company = null;
    _address = null;
    _photoUrl = null;
    _role = null;
    _profileLoaded = false;
    notifyListeners();
  }

  /// Load extended profile data from Firestore
  Future<void> loadProfile() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      final doc = await _db.collection('users').doc(u.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['isBlocked'] == true) {
          await signOut();
          return;
        }
        _phone = data['phone'] as String?;
        _company = data['company'] as String?;
        _address = data['address'] as String?;
        _photoUrl = data['photoUrl'] as String? ?? u.photoURL ?? '';
        _username = data['username'] as String?;
        _role = data['role'] as String?;
        _averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        _reviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
        _blockedUsers = List<String>.from(data['blockedUsers'] ?? []);
        _walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
        _availableToWithdraw = (data['availableToWithdraw'] ?? 0.0).toDouble();
      }
      _setPresence(true);
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    _profileLoaded = true;
    notifyListeners();
  }

  Future<void> refreshWallet() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      final doc = await _db.collection('users').doc(u.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _walletBalance = (data['walletBalance'] ?? 0.0).toDouble();
        _availableToWithdraw = (data['availableToWithdraw'] ?? 0.0).toDouble();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing wallet: $e');
    }
  }

  /// Update profile data in Firestore
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? company,
    String? address,
    String? username,
  }) async {
    final u = _auth.currentUser;
    if (u == null) return;
    
    if (name != null && name.isNotEmpty && name != u.displayName) {
      await u.updateDisplayName(name);
      // Wait for it to apply to the instance
      await u.reload();
      _currentUser = _auth.currentUser;
    }

    await _db.collection('users').doc(u.uid).set({
      if (name != null && name.isNotEmpty) 'name': name,
      if (name != null && name.isNotEmpty) 'displayName': name,
      'phone': phone,
      'company': company,
      'address': address,
      if (username != null && username.isNotEmpty) 'username': username,
    }, SetOptions(merge: true));
    _phone = phone;
    _company = company;
    _address = address;
    if (username != null) _username = username;
    notifyListeners();
  }

  Future<void> _saveUserToFirestore() async {
    final u = _auth.currentUser;
    if (u == null) return;
    
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    final doc = await _db.collection('users').doc(u.uid).get();
    Map<String, dynamic> updateData = {
      'uid': u.uid,
      if (u.isAnonymous) 'isGuest': true,
      'name': u.displayName ?? '',
      'displayName': u.displayName ?? '',
      'email': u.email ?? '',
      'photoUrl': u.photoURL ?? '',
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
    if (!doc.exists) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
      updateData['role'] = 'freelancer';
    }
    if (doc.exists && !(doc.data()?.containsKey('role') ?? false)) {
      updateData['role'] = 'freelancer';
    }

    if (!doc.exists || !(doc.data()?.containsKey('username') ?? false)) {
      final email = u.email ?? '';
      var base = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (base.isEmpty) base = u.isAnonymous ? 'guest' : 'user';
      final randomNum = (1000 + math.Random().nextInt(9000)).toString();
      updateData['username'] = '${base}_$randomNum';
    }

    await _db.collection('users').doc(u.uid).set(updateData, SetOptions(merge: true));
  }

  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      // Delete user data from Firestore
      await _db.collection('users').doc(u.uid).delete();
      // Delete the user from Firebase Authentication
      await u.delete();
      
      _phone = null;
      _company = null;
      _address = null;
      _photoUrl = null;
      _profileLoaded = false;
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      debugPrint('Delete Account Firebase error: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('Delete Account general error: $e');
      rethrow;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_currentUser != null) {
      if (state == AppLifecycleState.resumed) {
        _setPresence(true);
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
        _setPresence(false);
      }
    }
  }

  Future<void> _setPresence(bool isOnline) async {
    if (_currentUser == null) return;
    try {
      await _db.collection('users').doc(_currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting presence: $e');
    }
  }
}
