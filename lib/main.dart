import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_display/pages/landing_page.dart';
import 'package:spotify_display/utils/resize_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String alignment = prefs.getString('windowLocation') ?? 'top left';
  bool onTop = prefs.getBool('alwaysOnTop') ?? false;
  int screen = prefs.getInt('screenIndex') ?? 1;

  WindowOptions windowOptions = WindowOptions(
    backgroundColor: Colors.transparent,
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
    return MaterialApp(
      title: 'Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LandingPage(),
    );
  }
}
