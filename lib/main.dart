import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/providers/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/album/providers/album_provider.dart';
import 'features/couple/providers/couple_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/email_verification_screen.dart';
import 'features/home/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) {
            return ProfileProvider(
              context.read<AuthProvider>(),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            return AlbumProvider(
              context.read<AuthProvider>(),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            return CoupleProvider(
              context.read<AuthProvider>(),
            );
          },
        ),
      ],
      child: const DatyApp(),
    ),
  );
}

class DatyApp extends StatelessWidget {
  const DatyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Daty',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme.flutterTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (authProvider.isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (user == null) {
      return const LoginScreen();
    }

    if (!user.emailVerified) {
      return EmailVerificationScreen(
        email: user.email ?? '',
      );
    }

    return const HomeScreen();
  }
}