import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_page.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spanish Player',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const PlayerPage(),
    );
  }
}
