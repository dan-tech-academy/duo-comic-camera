import 'package:flutter/material.dart';

import 'capture/capture_screen.dart';
import 'theme/comic_theme.dart';

class DuoComicApp extends StatelessWidget {
  const DuoComicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duo Comic Camera',
      debugShowCheckedModeBanner: false,
      theme: ComicTheme.build(),
      home: const CaptureScreen(),
    );
  }
}
