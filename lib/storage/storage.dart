import 'dart:convert';

import 'package:spotify_display/storage.dart';

class StorageService {
  Storage storage = Storage();

  Future<bool> getStartUp() async {
    var startUp = await storage.get('startUp');
    if (startUp == null) {
      return false;
    }
    return startUp == 'true';
  }

  Future<void> saveStartUp(bool startUp) async {
    await storage.set('startUp', startUp.toString());
  }

  Future<String> getRefreshToken() async {
    return await storage.get('refreshToken');
  }

  Future<void> saveTokens({String? refreshToken, String? accessToken}) async {
    if (refreshToken != null) {
      await storage.set('refreshToken', refreshToken);
    }
    if (accessToken != null) {
      await storage.set('accessToken', accessToken);
    }
  }

  Future<Map<String, dynamic>> getTokens() async {
    var refreshToken = await storage.get('refreshToken');
    var accessToken = await storage.get('accessToken');
    return {'refreshToken': refreshToken, 'accessToken': accessToken};
  }

  Future<bool> getIsConnected() async {
    var isConnected = await storage.get('isConnected');
    if (isConnected == null) {
      return false;
    }
    return isConnected == 'true';
  }

  Future<void> saveIsConnected(bool isConnected) async {
    await storage.set('isConnected', isConnected.toString());
  }

  Future<void> saveWindowLocation(String windowLocation) async {
    await storage.set('windowLocation', windowLocation);
  }

  Future<String> getWindowLocation() async {
    return await storage.get('windowLocation') ?? "top left";
  }

  Future<void> saveAlwaysOnTop(bool alwaysOnTop) async {
    await storage.set('alwaysOnTop', alwaysOnTop);
  }

  Future<bool> getAlwaysOnTop() async {
    return await storage.get('alwaysOnTop') ?? false;
  }

  Future<void> saveScreenIndex(int index) async {
    await storage.set('windowIndex', index);
  }

  Future<int> getScreenIndex() async {
    return await storage.get('windowIndex') ?? 1;
  }
}
