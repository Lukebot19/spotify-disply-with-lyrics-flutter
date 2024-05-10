import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:spotify_display/pages/landing_page.dart';
import 'package:spotify_display/provider/main_provider.dart';
import 'package:spotify_display/storage.dart';
import 'package:spotify_display/storage/storage.dart';
import 'package:spotify_display/utils/resize_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.dotenv.load(fileName: 'lib/.env');

  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  // Initialize storage
  await Storage().init();

  await CentralManager.instance.setUp();

  launchAtStartup.setup(
    appName: packageInfo.appName,
    appPath: Platform.resolvedExecutable,
  );

  await launchAtStartup.enable();

  await windowManager.ensureInitialized();

  String alignment = await StorageService().getWindowLocation();
  bool onTop = await StorageService().getAlwaysOnTop();
  int screen = await StorageService().getScreenIndex();

  WindowOptions windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: onTop,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await positionWindow(alignment);
    await getScreenList(screen);
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
    await resizeWindow(350, 190);
    await positionWindow(alignment);
  });
  runApp(const MyApp());
}

Future<void> getScreenList(int index) async {
  List<window_size.Screen> screenList = await window_size.getScreenList();
  window_size.Screen? screenIndex;

  index = index - 1;
  if (index < 0) {
    index = 0;
  }

  if (index < screenList.length) {
    screenIndex = screenList[index];
  } else {
    screenIndex = null;
  }
  if (screenIndex != null) {
    final newFrame = screenIndex.frame;

    // Keep the same width and height, but update the location
    final updatedFrame = Rect.fromLTWH(
      newFrame.left,
      newFrame.top,
      350,
      190,
    );

    window_size.setWindowFrame(updatedFrame);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MainProvider(
      child: MaterialApp(
        title: 'Music Player',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: LandingPage(),
      ),
    );
  }
}
