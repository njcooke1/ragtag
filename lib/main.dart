import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
// For dynamic links
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
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Optional: Firebase AppCheck
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  // FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const RagtagApp());
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
    // 1) If the app is opened from a terminated state via a link:
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.link);
    }

    // 2) If the app is in background/foreground
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
      _handleDeepLink(dynamicLinkData.link);
    }).onError((error) {
      debugPrint("onLink error: $error");
    });
  }

  /// Decide where to navigate based on the deep link
  void _handleDeepLink(Uri deepLink) {
    // Example: https://ragtag.com/club?c=123
    if (deepLink.path.contains("club")) {
      final clubId = deepLink.queryParameters["c"] ?? "";
      if (clubId.isNotEmpty) {
        // You can fetch your club data from Firestore if you want
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
    // ...If you have other logic for interest groups, open forums, etc., handle it here.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 1) Remove banner
      debugShowCheckedModeBanner: false,
      title: 'Ragtag App',

      // 2) Start on '/home'
      initialRoute: '/home',

      // 3) Our named routes
      routes: {
        // Our RootPage decides whether to show OpeningLandingPage or the authenticated path
        '/home': (context) => const RootPage(),

        // User’s profile
        '/profilePage': (context) => const ProfilePage(),

        // Landing & Auth
        '/landing': (context) => const OpeningLandingPage(),
        '/sign-in': (context) => const SignInPage(),
        '/register': (context) => const RegistrationPage(),

        // The two pages for after Google sign-in:
        // If new => likes/dislikes, if existing => first-choice
        '/first-choice': (context) => const FirstChoicePage(),
        '/likes-dislikes': (context) => const LikesDislikesPage(),

        // For communities
        '/openingLandingPage': (context) => const OpeningLandingPage(),
        '/start-community': (context) => const StartCommunityPage(),
        '/find_community': (context) => const FindCommunityPage(),
        '/explore': (context) => const FindCommunityPage(),
        '/all_organizations': (context) => const AllOrganizationsPage(),

        // Clubs Profile
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

      // 4) Provide routes that need arguments via onGenerateRoute:
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
        // Fallback if no matches
        return null;
      },

      // Basic theming
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Lovelo-Black',
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

/// Decides whether to show the user an authenticated screen
/// or the opening landing page, based on whether user is logged in.
class RootPage extends StatelessWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Already logged in => go to FirstChoice
      return const FirstChoicePage();
    } else {
      // Not logged in => show OpeningLandingPage
      return const OpeningLandingPage();
    }
  }
}
