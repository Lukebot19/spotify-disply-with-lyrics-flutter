import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_display/utils/resize_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;

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

  @override
  void dispose() async {
    super.dispose();
    await resizeWindow(350, 190);
  }

  @override
  void initState() {
    windowManager.ensureInitialized();
    windowManager.setSize(const Size(350, 450), animate: true);
    super.initState();
    _loadPreferences();
    _getScreen();
  }

  void _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await _getScreenList();

    setState(() {
      _alwaysOnTop = prefs.getBool('alwaysOnTop') ?? false;
      int tempIndex = prefs.getInt('screenIndex') ?? 1;
      _screenIndex = _screenList![tempIndex - 1];
      _windowLocation = prefs.getString('windowLocation') ?? 'top left';
    });
  }

  void _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('alwaysOnTop', _alwaysOnTop);
    prefs.setInt('screenIndex', _screenList!.indexOf(_screenIndex!) + 1);
    prefs.setString('windowLocation', _windowLocation);
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
        190,
      );

      window_size.setWindowFrame(updatedFrame);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
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
          ),
          DropdownButton<String>(
            dropdownColor: Color.fromARGB(255, 34, 92, 0),
            value: _windowLocation,
            items: ['top left', 'top right', 'bottom left', 'bottom right']
                .map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  'Window Location: $value',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _setWindowLocation(value!);
              });
            },
          ),
          DropdownButton<String>(
            value: _screenIndex != null
                ? 'Screen ${_screenList!.indexOf(_screenIndex!) + 1}'
                : null,
            items: _screenListStrings?.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _setScreenIndex(
                    value != null ? int.parse(value.split(' ')[1]) - 1 : null);
              });
            },
          ),
          TextButton(
            onPressed: _clearPreferences,
            child: const Text(
              'Clear Preferences',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
