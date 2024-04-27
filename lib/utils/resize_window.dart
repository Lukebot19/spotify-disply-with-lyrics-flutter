import 'package:flutter/material.dart';
import 'package:spotify_display/storage/storage.dart';
import 'package:window_manager/window_manager.dart';

resizeWindow(double width, double height) async {
  await windowManager.ensureInitialized();

  await windowManager.setSize(Size(width, height), animate: false);

  String alignment = await StorageService().getWindowLocation();
  await positionWindow(alignment);
}

positionWindow(String alignment) async {
  await windowManager.ensureInitialized();

  switch (alignment) {
    case 'top left':
      await windowManager.setAlignment(Alignment.topLeft);
      break;
    case 'top right':
      await windowManager.setAlignment(Alignment.topRight);
      break;
    case 'bottom left':
      await windowManager.setAlignment(Alignment.bottomLeft);
      break;
    case 'bottom right':
      await windowManager.setAlignment(Alignment.bottomRight);
      break;
    default:
      await windowManager.setAlignment(Alignment.topLeft);
  }
}
