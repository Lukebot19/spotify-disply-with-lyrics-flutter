import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_display/utils/resize_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

import 'bluetooth_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _alwaysOnTop = false;
  window_size.Screen? _screenIndex;
  String _windowLocation = 'top left';
  List<window_size.Screen>? _screenList;
  window_size.Screen? _screen;
  List<String>? _screenListStrings;
  bool _loading = true;
  bool _startUp = false;

  @override
  void dispose() async {
    super.dispose();
  }

  @override
  void initState() {
    _loading = true;
    super.initState();
    _setSize();
    _loadPreferences();
    _getStartUp();
    _getScreen();
  }

  void _setSize() async {
    await resizeWindow(350, 450);
  }

  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await _getScreenList();

    setState(() {
      _alwaysOnTop = prefs.getBool('alwaysOnTop') ?? false;
      int tempIndex = prefs.getInt('screenIndex') ?? 1;
      try {
        _screenIndex = _screenList![tempIndex - 1];
      } catch (_) {
        _screenIndex = _screenList![0];
      }
      _windowLocation = prefs.getString('windowLocation') ?? 'top left';
    });
  }

  void _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alwaysOnTop', _alwaysOnTop);
    await prefs.setInt('screenIndex', _screenList!.indexOf(_screenIndex!) + 1);
    await prefs.setString('windowLocation', _windowLocation);
  }

  void _clearPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  void _toggleAlwaysOnTop() async {
    _alwaysOnTop = !_alwaysOnTop;
    _savePreferences();
    await windowManager.setAlwaysOnTop(_alwaysOnTop);
  }

  void _setScreenIndex(int? index) async {
    if (index != null && _screenList != null && index < _screenList!.length) {
      _screenIndex = _screenList![index];
    } else {
      _screenIndex = null;
    }
    _savePreferences();
    if (_screenIndex != null) {
      final newFrame = _screenIndex!.frame;

      // Keep the same width and height, but update the location
      final updatedFrame = Rect.fromLTWH(
        newFrame.left,
        newFrame.top,
        350,
        450,
      );

      window_size.setWindowFrame(updatedFrame);
      // await resizeWindow(350, 450);
    }
  }

  void _setWindowLocation(String location) async {
    _windowLocation = location;
    _savePreferences();
    positionWindow(_windowLocation);
  }

  Future<void> _getScreenList() async {
    _screenList = await window_size.getScreenList();
    _screenListStrings = List<String>.generate(
        _screenList?.length ?? 0, (index) => 'Screen ${index + 1}');
  }

  Future<void> _getScreen() async {
    _screen = await window_size.getCurrentScreen();
    _loading = false;
    setState(() {});
  }

  Future<void> _setStartUp(startUp) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('startUp', startUp);
    if (startUp) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  Future<void> _getStartUp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool startUp = prefs.getBool('startUp') ?? false;
    setState(() {
      _startUp = startUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            Navigator.pop(context);
            await resizeWindow(350, 190);
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _loading == false
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile(
                      title: const Text(
                        'Always on Top',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _alwaysOnTop,
                      onChanged: (bool value) {
                        setState(() {
                          _toggleAlwaysOnTop();
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Launch at Startup',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _startUp,
                      onChanged: (bool value) async {
                        await _setStartUp(value);

                        setState(() {
                          _startUp = value;
                        });
                      },
                      activeColor: Colors.green,
                    ),
                    const SizedBox(height: 20),
                    DropdownButton<String>(
                      dropdownColor: const Color(0xFF121212),
                      value: _windowLocation,
                      style: const TextStyle(color: Colors.white),
                      items: [
                        'top left',
                        'top right',
                        'bottom left',
                        'bottom right'
                      ].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            'Window Location: $value',
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _setWindowLocation(value!);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButton<String>(
                      dropdownColor: const Color(0xFF121212),
                      value: _screenIndex != null
                          ? 'Screen ${_screenList!.indexOf(_screenIndex!) + 1}'
                          : null,
                      style: const TextStyle(color: Colors.white),
                      items: _screenListStrings?.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _setScreenIndex(value != null
                              ? int.parse(value.split(' ')[1]) - 1
                              : null);
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () async {
                        // Show a dialog with a list of available Bluetooth devices
                        // to connect to
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return const ScannerView();
                        }));
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Connect to Bluetooth Device',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _clearPreferences,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Clear Preferences',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        exit(0);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Close App',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
