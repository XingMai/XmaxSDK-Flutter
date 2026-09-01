import 'package:flutter/material.dart';

import 'features/home/home_page.dart';
import 'ui/xlab_theme.dart';

class XLabApp extends StatelessWidget {
  const XLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XLab',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: XLabPalette.mint,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: XLabPalette.background,
        cardTheme: const CardThemeData(
          color: XLabPalette.surface,
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
