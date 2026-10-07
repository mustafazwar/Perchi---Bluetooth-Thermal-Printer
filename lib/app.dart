// TODO Implement this library.import 'dart:async';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parchi/ui/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/settings.dart';
import 'ui/flow.dart';
import 'ui/home_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';

class ParchiApp extends StatefulWidget {
  const ParchiApp({super.key});
  @override
  State<ParchiApp> createState() => _ParchiAppState();
}

class _ParchiAppState extends State<ParchiApp> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenForShares());
  }

  void _listenForShares() {
    // App was opened from another app's share sheet.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handle(files);
      ReceiveSharingIntent.instance.reset();
    }).catchError((_) {});
    // App was already running when something was shared to it.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle, onError: (_) {});
  }

  void _handle(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final f = files.first;
    final isText = f.type == SharedMediaType.text || f.type == SharedMediaType.url;
    intakeShared(f.path, isText: isText, isImage: f.type == SharedMediaType.image);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return MaterialApp(
      title: 'Parchi',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      themeMode: s.themeMode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // home: s.onboarded ? const HomeShell() : const OnboardingScreen(),
      home: s.onboarded ? const SplashScreen(nextScreen: HomeShell(),) : const OnboardingScreen(),
    );
  }
}
