import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'data/store.dart';
import 'screens/home.dart';
import 'screens/receive.dart';
import 'screens/setup.dart';
import 'speech/recogniser.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Demo recording builds only (--dart-define=LAFII_DEMO=true): expose the
  // accessibility tree so the walkthrough can be driven by element text.
  if (const bool.fromEnvironment('LAFII_DEMO')) {
    SemanticsBinding.instance.ensureSemantics();
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState(await Store.open());
  await state.load();
  runApp(LafiiApp(state: state));
  // Unpack the speech model in the background so "Speak instead" is ready
  // by the time a visit is open. Does not ask for the microphone.
  if (kSpeechEnabled) {
    Recogniser.instance.warmUp().then((_) {}, onError: (Object _) {});
  }
  // Debug builds: if a test clip has been pushed to the app's files folder,
  // recognise it without the microphone and log the result.
  if (kDebugMode && kSpeechEnabled) {
    final clip = File('${(await getApplicationDocumentsDirectory()).path}/selftest.wav');
    if (clip.existsSync()) {
      Recogniser.instance.recogniseFile(clip.path).then(
          (r) => debugPrint('vosk selftest final: $r'),
          onError: (Object e) => debugPrint('vosk selftest error: $e'));
    }
  }
}

class LafiiApp extends StatelessWidget {
  const LafiiApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Lafii',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootScreen(),
      ),
    );
  }
}

/// Picks the first screen: setup once, then refer or receive home.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.isSetUp) return const SetupScreen();
    return s.isReceiveMode ? const ReceiveHomeScreen() : const HomeScreen();
  }
}
