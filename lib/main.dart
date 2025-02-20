import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // App Check import
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

// Pages
import 'pages/sign_in_page.dart';
import 'pages/registration_page.dart';
import 'pages/first_choice.dart';
import 'pages/likes_dislikes.dart';
import 'pages/opening_landing_page.dart';
import 'pages/interest_groups_chat_page.dart';
import 'pages/start_community.dart';
import 'pages/find_community.dart';
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
import 'pages/profile_page.dart'; // Example profile page
import 'pages/fomo_feed_page.dart'; // For FOMO feed

// Handle background FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    print('Handling a background message: ${message.messageId}');
  } catch (e, stacktrace) {
    print('Error in background FCM handler: $e\n$stacktrace');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp();
    print('Firebase initialized.');
  } catch (e, stacktrace) {
    print('Error during Firebase.initializeApp(): $e\n$stacktrace');
  }

  // Activate Firebase App Check using DeviceCheck for iOS (and Play Integrity for Android)
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    print('AppCheck activated.');
  } catch (e, stacktrace) {
    print('Error activating AppCheck: $e\n$stacktrace');
  }

  // FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  print('FCM background handler set.');

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

  /// Listen for incoming dynamic links (initial + in-app)
  void _setupDynamicLinks() async {
    try {
      // 1) If the app is opened from a terminated state via a link:
      final PendingDynamicLinkData? initialLink =
          await FirebaseDynamicLinks.instance.getInitialLink();
      if (initialLink != null) {
        print('Initial dynamic link detected: ${initialLink.link}');
        _handleDeepLink(initialLink.link);
      }

      // 2) If the app is in background/foreground:
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

  /// Decide where to navigate based on the deep link
  void _handleDeepLink(Uri deepLink) {
    print('Handling deep link: $deepLink');
    // Example: https://ragtag.com/club?c=123
    if (deepLink.path.contains("club")) {
      final clubId = deepLink.queryParameters["c"] ?? "";
      if (clubId.isNotEmpty) {
        print('Navigating to clubs profile with clubId: $clubId');
        Navigator.pushNamed(
          context,
          '/clubs-profile',
          arguments: {
            'communityId': clubId,
            'communityData': {},
            'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          },
        );
      }
    }
    // Add additional deep link handling as needed.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ragtag App',
      
      // Start on
      initialRoute: '/landing',
      
      // Define named routes
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
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'No community data provided for Club.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
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
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'No Interest Group data provided.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
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
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'No Open Forum data provided.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
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
      },
      
      // Routes that need arguments are handled here.
      onGenerateRoute: (settings) {
        if (settings.name == '/club-chat') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ClubChatPage(
              clubId: args['clubId'],
              clubName: args['clubName'],
            ),
          );
        } else if (settings.name == '/club-events') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ClubEventsPage(
              clubId: args['clubId'],
              clubName: args['clubName'],
            ),
          );
        } else if (settings.name == '/group-chat') {
          final args = settings.arguments as Map<String, dynamic>;
          final communityId = args['communityId'] ?? '';
          final communityName = args['communityName'] ?? '';
          return MaterialPageRoute(
            builder: (context) => InterestGroupChatPage(
              communityId: communityId,
              communityName: communityName,
            ),
          );
        }
        return null;
      },
      
      // Basic theming
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Lovelo',
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.dark,
    );
  }
}

/// Decides whether to show an authenticated screen or the landing page.
class RootPage extends StatelessWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    print('RootPage build. Current user: $user');
    if (user != null) {
      print('User detected. Routing to FirstChoicePage.');
      return const FirstChoicePage();
    } else {
      print('No user detected. Routing to OpeningLandingPage.');
      return const OpeningLandingPage();
    }
  }
}

/* 
// Uncomment this fallback widget for diagnostic purposes:
// Use it as the home widget to check if your Flutter UI loads correctly on iOS.

class TestHomePage extends StatelessWidget {
  const TestHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Hello, iOS Build is working!')),
    );
  }
}
