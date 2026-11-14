import 'package:flutter/material.dart';

import 'marketplace_palette.dart';

class MarketplaceTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F8F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: marketplaceTeal,
          brightness: Brightness.light,
          primary: marketplaceTeal,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: marketplaceInk,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.white,
          titleTextStyle: TextStyle(
            color: marketplaceInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: marketplaceTeal.withValues(alpha: 0.12),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: Colors.white,
          indicatorColor: marketplaceTeal.withValues(alpha: 0.12),
          selectedIconTheme: const IconThemeData(color: marketplaceTeal),
          unselectedIconTheme: const IconThemeData(color: marketplaceMuted),
          selectedLabelTextStyle: const TextStyle(color: marketplaceTeal, fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F8F8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: marketplaceMuted, fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: marketplaceLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: marketplaceLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: marketplaceTeal, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: marketplaceTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: marketplaceTeal,
            side: const BorderSide(color: marketplaceTeal),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        dividerColor: marketplaceLine,
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101A1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: marketplaceTeal,
          brightness: Brightness.dark,
          primary: const Color(0xFF5BC6B8),
        ),
      );
}
