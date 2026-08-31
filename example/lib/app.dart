import 'package:flutter/material.dart';

import 'features/home/home_page.dart';

class XmaxSdkExampleApp extends StatelessWidget {
  const XmaxSdkExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF070A0F);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XmaxSDK Example',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DF0B5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: background,
        cardTheme: const CardThemeData(
          color: Color(0xFF111820),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
