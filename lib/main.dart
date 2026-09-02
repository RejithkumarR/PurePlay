import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/home_screen.dart';
import 'services/audio_playback_service.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Start Flutter immediately. AudioService initialization can wait on
  // Android platform setup and must not block the application startup screen.
  runApp(const PurePlayApp());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize background audio after the Flutter UI has been attached.
  // This prevents the native splash screen from remaining visible if the
  // audio service takes time to connect to its Android service.
  try {
    await AudioPlaybackService.initialize();
  } catch (error) {
    debugPrint('Audio service initialization failed: $error');
  }
}

class PurePlayApp extends StatelessWidget {
  const PurePlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PurePlay v1.0.2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
