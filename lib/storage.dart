import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class Storage {
  // A class to handle the basic storage operations
  init() async {
    // Initialize the Hive storage
    if (!kIsWeb && !Hive.isBoxOpen("secureBox")) {
      Hive.init((await getApplicationDocumentsDirectory()).path);
    }
  }

  Future<void> set(String key, dynamic value) async {
    // Set a value in the storage
    final box = await Hive.openBox('secureBox');
    await box.put(key, value);
    await box.close();
  }

  Future<dynamic> get(String key) async {
    // Get a value from the storage
    final box = await Hive.openBox('secureBox');
    var temp = await box.get(key);
    await box.close();
    return temp;
  }

  Future clear() async {
    // Clear the storage
    final box = await Hive.openBox('secureBox');
    await box.clear();
    await Hive.close();
  }
}
