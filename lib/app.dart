import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/sticker_repository.dart';
import 'scrapbook/scrapbook_page.dart';
import 'theme/memtickers_theme.dart';

class MemtickersApp extends StatelessWidget {
  const MemtickersApp({super.key, required this.repository});

  final StickerRepository repository;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = memtickersTheme(lightDynamic ?? fallbackScheme(Brightness.light));
        final dark = memtickersTheme(darkDynamic ?? fallbackScheme(Brightness.dark));
        return MaterialApp(
          title: 'Memtickers',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final currentScheme = isDark ? dark.colorScheme : light.colorScheme;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarColor: currentScheme.surface,
                  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                ),
                child: ScrapbookPage(repository: repository),
              );
            },
          ),
        );
      },
    );
  }
}
