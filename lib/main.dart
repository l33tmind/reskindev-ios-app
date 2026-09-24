import 'package:flutter/foundation.dart';
import 'package:seo/seo.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'providers/auth_provider.dart' as ap;
import 'providers/gig_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/page_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/chat_provider.dart';
import 'router.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _initMessaging() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    String? token = await messaging.getToken();
    if (token != null) {
      debugPrint("FCM Token: $token");
    }
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          appRouter.go(response.payload!);
        }
      },
    );

    // Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data['route'] != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.go(message.data['route']);
        });
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['route'] != null) {
        appRouter.go(message.data['route']);
      }
    });

    // iOS Foreground Notifications
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false, // Set to false because we use flutterLocalNotificationsPlugin to show it manually below
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['route'],
        );
      }
    });
  } catch (e) {
    debugPrint("Messaging Init Error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Messaging safely (web non-blocking)
  if (!kIsWeb) {
    _initMessaging();
  }

  // Android status bar transparent

  // Lock orientation to portrait for mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('theme_mode');
  ThemeMode initialThemeMode = ThemeMode.system;
  if (themeStr != null) {
    if (themeStr == 'system') initialThemeMode = ThemeMode.system;
    else if (themeStr == 'dark') initialThemeMode = ThemeMode.dark;
    else initialThemeMode = ThemeMode.light;
  } else {
    final isDark = prefs.getBool('isDarkMode');
    if (isDark != null) {
      initialThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  runApp(MyApp(initialThemeMode: initialThemeMode));

}

class MyApp extends StatelessWidget {
  final ThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  @override
  Widget build(BuildContext context) {
    return SeoController(
      enabled: true,
      tree: WidgetTree(context: context),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ap.AuthProvider()),
          ChangeNotifierProxyProvider<ap.AuthProvider, GigProvider>(
            create: (_) => GigProvider(),
            update: (_, auth, previous) => (previous ?? GigProvider())..updateAuth(auth),
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider(initialThemeMode)),
          ChangeNotifierProvider(create: (_) => PageProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
        ],
        child: const _AppRouter(),
      ),
    );
  }
}

/// Separate StatelessWidget so that only themeMode changes
/// trigger a rebuild — NOT the entire widget tree including the router.
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp.router(
          key: const ValueKey('app_router'),
          title: 'Reskindev',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
