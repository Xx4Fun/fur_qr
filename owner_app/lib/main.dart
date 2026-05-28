import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'firebase_options.dart';
import 'models/pet.dart';
import 'screens/auth_screen.dart';
import 'screens/pet_detail_screen.dart';
import 'services/supabase_service.dart';

import 'screens/main_layout.dart';
import 'theme.dart';

// Global Isar instance
late Isar isar;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed: $e");
  }

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: 'https://lioqpvbitlobracvkttp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpb3FwdmJpdGxvYnJhY3ZrdHRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NDUyNzYsImV4cCI6MjA5NTEyMTI3Nn0.7P3aGsYA7i8jU6xFzmZnmgVj_Acj0YD-JGSK9KeTCk8', // Using the legacy anon key as it is commonly supported
  );

  // 3. Initialize Isar Local Database
  final dir = await getApplicationDocumentsDirectory();
  isar = await Isar.open(
    [PetSchema],
    directory: dir.path,
  );

  runApp(const FurParentApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FurParentApp extends StatelessWidget {
  const FurParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Fur Parent Bridge',
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.setupAuthListener(context);
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Check initial link if app was closed
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Deep link init error: $e");
    }

    // Handle links when app is running in foreground/background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("Deep link stream error: $err");
    });
  }

  void _handleDeepLink(Uri uri) async {
    final tagId = uri.queryParameters['id'];
    if (tagId != null && Supabase.instance.client.auth.currentSession != null) {
      // Find the pet locally by tagId
      final pet = await isar.pets.filter().tagIdEqualTo(tagId).findFirst();
      if (pet != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => PetDetailScreen(pet: pet))
        );
      } else {
        // Tag doesn't belong to this owner, or hasn't synced yet.
        debugPrint("Scanned tag does not belong to the logged-in owner's local cache.");
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const MainLayoutScreen();
    }
    return const AuthScreen();
  }
}