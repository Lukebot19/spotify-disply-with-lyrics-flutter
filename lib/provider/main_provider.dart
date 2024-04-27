import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../states/main_state.dart';


class MainProvider extends StatelessWidget {
  final Widget child;

  const MainProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MainState>(
      create: (_) => MainState(),
      child: child,
    );
  }
}
