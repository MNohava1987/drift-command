import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/screens/scenario_picker_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DriftCommandApp());
}

class DriftCommandApp extends StatelessWidget {
  const DriftCommandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScenarioPickerScreen(),
    );
  }
}
