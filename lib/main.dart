import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/auth_service.dart';
import 'home.dart';
import 'navable_design.dart';
import 'password_recovery.dart';
import 'welcome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final initialRecovery =
      Uri.base.fragment.contains('type=recovery') ||
      Uri.base.queryParameters['type'] == 'recovery';
  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to start NavAble.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(MyApp(initialRecovery: initialRecovery));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialRecovery = false});

  final bool initialRecovery;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;
  bool _recoveryOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRecovery());
    }
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event != AuthChangeEvent.passwordRecovery) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openRecovery();
      });
    });
  }

  void _openRecovery() {
    if (!mounted ||
        _recoveryOpen ||
        Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    _recoveryOpen = true;
    _navigatorKey.currentState
        ?.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const PasswordRecoveryScreen(),
          ),
          (route) => false,
        )
        .whenComplete(() => _recoveryOpen = false);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: NavAblePreferences.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'NavAble',
        debugShowCheckedModeBanner: false,
        theme: NavAbleTheme.light,
        darkTheme: NavAbleTheme.dark,
        themeMode: themeMode,
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: NavAblePreferences.textScale,
          builder: (context, textScale, _) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
        home: const AuthCheck(),
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) => AuthService().isLoggedIn()
          ? const HomeScreen()
          : const WelcomeScreen(),
    );
  }
}
