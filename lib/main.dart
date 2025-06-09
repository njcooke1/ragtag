import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import your notification service.
import 'services/notification_service.dart';

// Pages
import 'pages/sign_in_page.dart';
import 'pages/registration_page.dart';
import 'pages/first_choice.dart';
import 'pages/likes_dislikes.dart';
import 'pages/opening_landing_page.dart';
import 'pages/interest_groups_chat_page.dart';
import 'pages/start_community.dart';
import 'pages/find_community.dart';
import 'package:ragtagrevived/pages/review_page.dart';
import 'pages/all_organizations.dart';
import 'pages/clubs_profile_page.dart';
import 'pages/interest_groups_profile_page.dart';
import 'pages/open_forums_profile_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/edit_community_page.dart';
import 'pages/club_chat_page.dart';
import 'pages/club_events_page.dart';
import 'pages/story_view_page.dart';
import 'widgets/story_editor.dart';
import 'pages/profile_page.dart';
import 'pages/fomo_feed_page.dart';
import 'pages/chat_page.dart'; // User chat page.

// Global secure storage instance.
final FlutterSecureStorage secureStorage = FlutterSecureStorage();

// Global navigator key for notifications and deep links.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Initialize flutter_local_notifications plugin.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Handles background FCM messages.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    print('Handling a background message: ${message.messageId}');
  } catch (e, stacktrace) {
    print('Error in background FCM handler: $e\n$stacktrace');
  }
}

/// Request notification permissions.
Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  print('Notification permission status: ${settings.authorizationStatus}');
}

/// Retrieve and print the APNs token.
Future<void> getAPNSTokenAndPrint() async {
  String? token = await FirebaseMessaging.instance.getAPNSToken();
  print('APNs token: $token');
}

/// Initialize local notifications.
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iOSSettings =
      DarwinInitializationSettings();
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iOSSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  print('Local notifications initialized.');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge mode.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp();
    print('Firebase initialized.');
  } catch (e, stacktrace) {
    print('Error during Firebase.initializeApp(): $e\n$stacktrace');
  }

  // Activate Firebase App Check.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    print('AppCheck activated.');
  } catch (e, stacktrace) {
    print('Error activating AppCheck: $e\n$stacktrace');
  }

  // Set up FCM background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print('FCM background handler set.');

  await requestNotificationPermission();
  await getAPNSTokenAndPrint();
  await initializeLocalNotifications();

  // Initialize notification service.
  await NotificationService().initialize(navigatorKey: navigatorKey);

  // Listen for foreground messages.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Received a foreground message: ${message.messageId}');
    NotificationService().showLocalNotification(message);
  });

  // Listen for notification taps.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('onMessageOpenedApp: ${message.messageId}');
    final data = message.data;
    final chatType = data['chatType'];
    if (chatType != null) {
      switch (chatType) {
        case "user":
          Navigator.pushNamed(navigatorKey.currentState!.context, '/user-chat', arguments: {
            'chatId': data['chatId'],
            'otherUserId': data['otherUserId'],
            'otherUserName': data['otherUserName'],
            'otherUserPhotoUrl': data['otherUserPhotoUrl'],
          });
          break;
        case "club":
          Navigator.pushNamed(navigatorKey.currentState!.context, '/club-chat', arguments: {
            'clubId': data['clubId'],
            'clubName': data['clubName'],
          });
          break;
        case "interestGroup":
          Navigator.pushNamed(navigatorKey.currentState!.context, '/group-chat', arguments: {
            'communityId': data['communityId'],
            'communityName': data['communityName'],
          });
          break;
        case "openForum":
          Navigator.pushNamed(navigatorKey.currentState!.context, '/forum-chat', arguments: {
            'forumId': data['forumId'],
            'forumName': data['forumName'],
          });
          break;
        default:
          print('Unhandled chatType in onMessageOpenedApp: $chatType');
          break;
      }
    }
  });

  // Optionally check for a stored auth token.
  final String? storedAuthToken = await secureStorage.read(key: 'auth_token');
  if (storedAuthToken != null) {
    print('Found auth token in secure storage: $storedAuthToken');
    // For custom tokens, sign in explicitly:
    // await FirebaseAuth.instance.signInWithCustomToken(storedAuthToken);
  } else {
    print('No auth token found in secure storage.');
  }

  runApp(const RagtagApp());
  print('App launched.');
}

class RagtagApp extends StatefulWidget {
  const RagtagApp({Key? key}) : super(key: key);

  @override
  State<RagtagApp> createState() => _RagtagAppState();
}

class _RagtagAppState extends State<RagtagApp> {
  @override
  void initState() {
    super.initState();
    _setupDynamicLinks();
  }

  void _setupDynamicLinks() async {
    try {
      final PendingDynamicLinkData? initialLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (initialLink != null) {
        print('Initial dynamic link detected: ${initialLink.link}');
        _handleDeepLink(initialLink.link);
      }
      FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
        print('Dynamic link received in-app: ${dynamicLinkData.link}');
        _handleDeepLink(dynamicLinkData.link);
      }).onError((error) {
        debugPrint("Dynamic link onLink error: $error");
      });
    } catch (e, stacktrace) {
      print('Error setting up dynamic links: $e\n$stacktrace');
    }
  }

  void _handleDeepLink(Uri deepLink) {
    print('Handling deep link: $deepLink');
    final chatType = deepLink.queryParameters["chatType"];
    if (chatType != null) {
      switch (chatType) {
        case "user":
          final chatId = deepLink.queryParameters["chatId"] ?? "";
          final otherUserId = deepLink.queryParameters["otherUserId"] ?? "";
          final otherUserName = deepLink.queryParameters["otherUserName"] ?? "";
          final otherUserPhotoUrl = deepLink.queryParameters["otherUserPhotoUrl"] ?? "";
          if (chatId.isNotEmpty) {
            Navigator.pushNamed(context, '/user-chat', arguments: {
              'chatId': chatId,
              'otherUserId': otherUserId,
              'otherUserName': otherUserName,
              'otherUserPhotoUrl': otherUserPhotoUrl,
            });
          }
          break;
        case "club":
          final clubId = deepLink.queryParameters["clubId"] ?? "";
          final clubName = deepLink.queryParameters["clubName"] ?? "";
          if (clubId.isNotEmpty) {
            Navigator.pushNamed(context, '/club-chat', arguments: {
              'clubId': clubId,
              'clubName': clubName,
            });
          }
          break;
        case "interestGroup":
          final communityId = deepLink.queryParameters["communityId"] ?? "";
          final communityName = deepLink.queryParameters["communityName"] ?? "";
          if (communityId.isNotEmpty) {
            Navigator.pushNamed(context, '/group-chat', arguments: {
              'communityId': communityId,
              'communityName': communityName,
            });
          }
          break;
        case "openForum":
          final forumId = deepLink.queryParameters["forumId"] ?? "";
          final forumName = deepLink.queryParameters["forumName"] ?? "";
          if (forumId.isNotEmpty) {
            Navigator.pushNamed(context, '/forum-chat', arguments: {
              'forumId': forumId,
              'forumName': forumName,
            });
          }
          break;
        default:
          print('Unhandled chatType in deep link: $chatType');
          break;
      }
    } else {
      if (deepLink.path.contains("club")) {
        final clubId = deepLink.queryParameters["c"] ?? "";
        if (clubId.isNotEmpty) {
          Navigator.pushNamed(context, '/clubs-profile', arguments: {
            'communityId': clubId,
            'communityData': {},
            'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // -------------- THEMING ----------------
    const baseFont = 'Lovelo-Black';

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: baseFont,
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        bodySmall: TextStyle(color: Colors.black),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: baseFont,
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white),
      ),
    );

    // -------------- APP ----------------
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Ragtag App',

      // ROUTES (unchanged)
      home: const RootPage(),
      routes: {
        '/home': (context) => const RootPage(),
        '/profilePage': (context) => const ProfilePage(),
        '/landing': (context) => const OpeningLandingPage(),
        '/sign-in': (context) => const SignInPage(),
        '/register': (context) => const RegistrationPage(),
        '/first-choice': (context) => const FirstChoicePage(),
        '/likes-dislikes': (context) => const LikesDislikesPage(),
        '/openingLandingPage': (context) => const OpeningLandingPage(),
        '/start-community': (context) => const StartCommunityPage(),
        '/find_community': (context) => const FindCommunityPage(),
        '/explore': (context) => const FindCommunityPage(),
        '/all_organizations': (context) => const AllOrganizationsPage(),
        '/clubs-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('No community data provided for Club.', style: TextStyle(color: Colors.red))),
            );
          }
          final communityId = args['communityId'] as String? ?? '';
          final communityData = args['communityData'] as Map<String, dynamic>? ?? {};
          final userId = args['userId'] as String? ?? '';
          return ClubsProfilePage(
            communityId: communityId,
            communityData: communityData,
            userId: userId,
          );
        },
        '/interest-groups-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('No Interest Group data provided.', style: TextStyle(color: Colors.red))),
            );
          }
          final communityId = args['communityId'] as String? ?? '';
          final communityData = args['communityData'] as Map<String, dynamic>? ?? {};
          final userId = args['userId'] as String? ?? '';
          final collectionName = args['collectionName'] as String? ?? 'interestGroups';
          return RedesignedInterestGroupsPage(
            communityId: communityId,
            communityData: communityData,
            userId: userId,
            collectionName: collectionName,
          );
        },
        '/open-forums-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('No Open Forum data provided.', style: TextStyle(color: Colors.red))),
            );
          }
          final communityId = args['communityId'] as String? ?? '';
          final communityData = args['communityData'] as Map<String, dynamic>? ?? {};
          final userId = args['userId'] as String? ?? '';
          return OpenForumsProfilePage(
            communityId: communityId,
            communityData: communityData,
            userId: userId,
          );
        },
        '/admin-dashboard': (context) => const AdminDashboardPage(),
        '/edit_community': (context) => EditCommunityPage(),
        '/fomo_feed': (context) => const FomoFeedPage(),
        '/user-chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null || args['chatId'] == null) {
            return const Scaffold(
              body: Center(child: Text('No chat data provided for user chat.', style: TextStyle(color: Colors.red))),
            );
          }
          return ChatPage(
            chatId: args['chatId'],
            otherUserId: args['otherUserId'] ?? '',
            otherUserName: args['otherUserName'] ?? '',
            otherUserPhotoUrl: args['otherUserPhotoUrl'] ?? '',
          );
        },
        '/club-chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null || args['clubId'] == null) {
            return const Scaffold(
              body: Center(child: Text('No chat data provided for club chat.', style: TextStyle(color: Colors.red))),
            );
          }
          return ClubChatPage(
            clubId: args['clubId'],
            clubName: args['clubName'] ?? '',
          );
        },
        '/group-chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null || args['communityId'] == null) {
            return const Scaffold(
              body: Center(child: Text('No chat data provided for interest group chat.', style: TextStyle(color: Colors.red))),
            );
          }
          return InterestGroupChatPage(
            communityId: args['communityId'],
            communityName: args['communityName'] ?? '',
          );
        },
        '/forum-chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null || args['forumId'] == null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'No chat data provided for open forum chat.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }
          return OpenForumsProfilePage(
            communityId: args['forumId'], // treat forumId as communityId
            communityData: args['forumData'] ?? {}, // pass in any available forum data, or an empty map
            userId: args['userId'] ?? FirebaseAuth.instance.currentUser?.uid ?? '',
          );
        },
      },
      onGenerateRoute: (settings) => null, // keep custom logic if you add any
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // 🌗 follow device preference
    );
  }
}

/// RootPage now uses a StreamBuilder to listen to FirebaseAuth.authStateChanges().
class RootPage extends StatelessWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(      // listen to auth state
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user != null) {
          print('User detected. Routing to FirstChoicePage.');
          return const FirstChoicePage();
        } else {
          print('No user detected. Routing to OpeningLandingPage.');
          return const OpeningLandingPage();
        }
      },
    );
  }
}
