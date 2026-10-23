import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../theme.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart' show MicrophoneAccessDeniedException;

import '../speech/recogniser.dart';
import '../ui/widgets.dart';
import 'confirm.dart';
import 'visit.dart';

/// 16 Consent before recording (10.1, 10.2).
///
/// Reachable only when [kSpeechEnabled] is true. Speech is the last thing
/// built; the prompt audio and on-device recogniser are not wired yet.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.visit});
  final AncVisit visit;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  String _language = 'Dagbani';

  @override
  void initState() {
    super.initState();
    // Use the time spent asking for consent to finish loading the model.
    Recogniser.instance.warmUp().then((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.patients[widget.visit.patientId]!;
    return AppScreen(
      header: ScreenHeader(
          context_: patientLine(s, p), title: 'Ask before recording', divider: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          LabeledField(
            label: 'Her language',
            child: Segmented<String>(
              options: const [('Dagbani', 'Dagbani'), ('English', 'English')],
              value: _language,
              onChanged: (l) => setState(() => _language = l ?? _language),
            ),
          ),
          const SizedBox(height: 16),
          // Prompt audio is not bundled yet; the officer reads the text below.
          const SecondaryButton('Play the prompt to her'),
          const SizedBox(height: 16),
          const Callout(
            title: 'What she hears',
            body: 'The nurse would like to record her notes about your visit. The '
                'recording stays on this phone and is deleted once she has checked it. '
                'If you say no, your care is exactly the same.',
          ),
        ],
      ),
      bottom: BottomBar(children: [
        SecondaryButton('She said no', fontSize: 14, onPressed: () {
          s.recordConsent(widget.visit.id, given: false, language: _language);
          Navigator.pop(context);
        }),
        PrimaryButton('She agreed', onPressed: () {
          s.recordConsent(widget.visit.id, given: true, language: _language);
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => RecordingScreen(visit: widget.visit, language: _language)));
        }),
      ]),
    );
  }
}

/// 06 Speak the summary. Elapsed seconds only: no waveform, pulse or
/// microphone icon (2.7).
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key, required this.visit, required this.language});
  final AncVisit visit;
  final String language;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  Timer? _timer;
  int _seconds = 0;
  String? _problem;
  bool _stopping = false;

  /// False until the microphone is actually feeding the recogniser. The
  /// first use on a phone unpacks the speech model, which can take a while;
  /// anything said before this is true is not heard.
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    try {
      await Recogniser.instance.start();
    } on MicrophoneAccessDeniedException {
      if (mounted) {
        setState(() => _problem =
            'The microphone is not allowed for this app. Allow it in Android settings, '
            'or switch to tapping.');
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _problem =
            'Speech recognition could not start on this phone. Switch to tapping.\n\n'
            'Details for the team: $e');
      }
      return;
    }
    if (!mounted) {
      await Recogniser.instance.cancel();
      return;
    }
    setState(() => _listening = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_stopping) Recogniser.instance.cancel();
    super.dispose();
  }

  Future<void> _stopAndReview() async {
    if (_stopping) return;
    _stopping = true;
    _timer?.cancel();
    final transcript = await Recogniser.instance.stop();
    if (!mounted) return;
    final notes = AppScope.read(context).applySpeech(widget.visit, transcript);
    // The transcript is shown once on the next screen and never stored.
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => ConfirmScreen(
                visit: widget.visit,
                spoken: true,
                notes: notes,
                heard: transcript,
                unrecognised: Recogniser.instance.unrecognised,
                peakDb: Recogniser.instance.peakDb)));
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stop recording?', style: T.display(20)),
        content: Text('The recording is deleted. You can enter the visit by tapping.',
            style: T.bodyText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep recording')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.patients[widget.visit.patientId]!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: AppScreen(
        scroll: false,
        header: ScreenHeader(
            context_: patientLine(s, p),
            title: 'Antenatal visit ${widget.visit.contactNumber}',
            divider: true),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Callout(
              kind: CalloutKind.success,
              title: 'Consent given in ${widget.language}',
              body: 'Audio is deleted from this phone as soon as you confirm the fields.',
            ),
            Expanded(
              child: _problem != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(_problem!, style: T.bodyText),
                    )
                  : !_listening
                      ? Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                              'Not listening yet. The first time on a phone this can take '
                              'up to half a minute. Start speaking when the seconds counter '
                              'appears.',
                              style: T.bodyText),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Recording. Speak now.', style: T.ui(15)),
                            Text('$_seconds',
                                style: T.mono(80, w: FontWeight.w600, color: C.navy, height: 1)),
                            Text('seconds', style: T.ui(15)),
                          ],
                        ),
            ),
          ],
        ),
        bottom: Container(
          padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_problem == null)
                PrimaryButton('Stop and review fields',
                    height: 56, onPressed: _listening ? _stopAndReview : null),
              const SizedBox(height: 10),
              SecondaryButton('Switch to tapping',
                  height: Sp.minTarget, onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}
