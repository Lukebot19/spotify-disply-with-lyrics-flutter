import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';

import '../models/music.dart';

class MainState extends ChangeNotifier {
  // Song info
  int? _red;
  int? _green;
  int? _blue;
  Music _music = Music();
  bool _currentTrack = false;

  // LED Stuff
  GattCharacteristic? _ledCharacteristic;

  // Getters
  GattCharacteristic? get ledCharacteristic => _ledCharacteristic;
  int get red => _red!;
  int get green => _green!;
  int get blue => _blue!;
  Music get music => _music;
  bool get currentTrack => _currentTrack;


  // Setters
  void setCurrentTrack(bool currentTrack) {
    _currentTrack = currentTrack;
    notifyListeners();
  }
  
  void setMusic(Music music) {
    _music = music;
    notifyListeners();
  }

  void setLedCharacteristic(GattCharacteristic? characteristic) {
    _ledCharacteristic = characteristic;
    notifyListeners();
  }
  
  void setColours(int red, int green, int blue) {
    _red = red;
    _green = green;
    _blue = blue;
    notifyListeners();
  }

  Uint8List createByteList(int i2, int i3, int i) {
    return Uint8List.fromList([
      -51,
      80,
      128,
      96,
      0,
      i2 & 0xFF,
      i3 & 0xFF,
      i & 0xFF,
      0,
      255,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      18
    ]);
  }

  void sendCommand() {
    if (_ledCharacteristic != null) {
      Uint8List byteList = createByteList(
        _green!,
        _blue!,
        _red!,
      );
      CentralManager.instance.writeCharacteristic(
        _ledCharacteristic!,
        value: byteList,
        type: GattCharacteristicWriteType.withResponse,
      );
    }
  }
}
