import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LocalTubeApp extends StatelessWidget {
  const LocalTubeApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LocalTube',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
    );
  }
}
