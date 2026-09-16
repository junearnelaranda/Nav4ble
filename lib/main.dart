import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'navable_design.dart';
import 'welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: NavAblePreferences.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
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
        home: const WelcomeScreen(),
      ),
    );
  }
}