import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'confirm.dart';
import 'speech.dart';

void openVisitFor(BuildContext context, Patient p) {
  // Start the visit before navigating: it saves and notifies listeners,
  // which must not happen while the next screen is being built.
  final visit = AppScope.read(context).startVisit(p);
  Navigator.push(context, MaterialPageRoute(builder: (_) => VisitScreen(visit: visit)));
}

/// "Fati Alhassan · 28 · Kpasenkpe"
String patientLine(AppState s, Patient p) {
  final age = p.ageAt(s.now);
  return [p.fullName, ?age?.toString(), p.community].join(' · ');
}

/// 05 Visit by tap. A complete path on its own; every field is here.
/// Every change is written to the phone immediately (9.1).
class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key, required this.visit});
  final AncVisit visit;

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  AncVisit get v => widget.visit;
  late final AppState s = AppScope.read(context);
  late final Pregnancy g = s.pregnancies[v.pregnancyId]!;
  late final Patient p = s.patients[v.patientId]!;
  late final _note = TextEditingController(text: v.freeNote ?? '');
  int _generation = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() => s.saveVisit(v);

  void _setMeasure(Measure m, String text) {
    v.setMeasure(m, num.tryParse(text));
    _save();
  }

  void _setWeeks(String text) {
    final w = int.tryParse(text);
    if (w == null) return;
    g.gestationalWeeks = w;
    s.putPregnancy(g);
  }

  void _setSign(DangerSign sign, TriState value) {
    setState(() {
      final f = v.sign(sign);
      if (value == TriState.notAsked) {
        f.setManual(null);
      } else {
        f.setManual(value);
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    return AppScreen(
      header: ScreenHeader(
        context_: patientLine(s, p),
        title: 'Antenatal visit ${v.contactNumber}',
        divider: true,
        trailing: kSpeechEnabled
            ? SecondaryButton('Speak instead',
                height: Sp.minTarget,
                fontSize: 14,
                onPressed: () async {
                  await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ConsentScreen(visit: v)));
                  // Speech may have filled values; rebuild the inputs from the visit.
                  if (mounted) setState(() => _generation++);
                })
            : null,
      ),
      body: Column(
        key: ValueKey(_generation),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LabeledField(
                  label: 'Blood pressure',
                  child: Row(children: [
                    Expanded(child: _NumInput(field: v.systolic, onChanged: (t) => _setMeasure(Measure.systolic, t))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('/', style: T.mono(17, color: C.muted)),
                    ),
                    Expanded(child: _NumInput(field: v.diastolic, onChanged: (t) => _setMeasure(Measure.diastolic, t))),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: LabeledField(
                  label: 'Weeks pregnant',
                  child: _NumInput(initial: '${g.gestationalWeeks}', onChanged: _setWeeks),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle('Danger signs',
              size: 15, trailing: Text('Blank means not asked', style: T.ui(13))),
          for (final sign in DangerSign.values)
            TriStateRow(
              label: sign.label,
              value: v.sign(sign).value ?? TriState.notAsked,
              onChanged: (t) => _setSign(sign, t),
            ),
          const SizedBox(height: 20),
          const SectionTitle('Measurements', size: 15),
          _grid([
            for (final m in const [
              Measure.temperatureC,
              Measure.weightKg,
              Measure.pulse,
              Measure.fundalHeightCm,
              Measure.fetalHeartRate,
              Measure.haemoglobin,
            ])
              LabeledField(
                label: '${m.label} (${m.unit})',
                child: _NumInput(
                  field: v.measure(m),
                  decimal: m.isDecimal,
                  onChanged: (t) => _setMeasure(m, t),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Urine protein (dipstick)',
            caption: 'Blank means not tested',
            child: Segmented<int>(
              options: const [(0, 'Nil'), (1, '1+'), (2, '2+'), (3, '3+'), (4, '4+')],
              value: v.urineProtein?.value,
              allowClear: true,
              fontSize: 14,
              onChanged: (x) {
                setState(() => v.setMeasure(Measure.urineProtein, x));
                _save();
              },
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Note',
            child: TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              style: T.ui(15, color: C.strong, height: 1.45),
              onChanged: (t) {
                v.freeNote = t.trim().isEmpty ? null : t;
                _save();
              },
            ),
          ),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton('Save and continue',
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => ConfirmScreen(visit: v)));
              // Values may have been edited on the confirm screen.
              if (mounted) setState(() => _generation++);
            }),
      ]),
    );
  }

  Widget _grid(List<Widget> cells) => Column(children: [
        for (var i = 0; i < cells.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: cells[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < cells.length ? cells[i + 1] : const SizedBox()),
          ]),
        ]
      ]);
}

/// Numeric input on the system number pad (2.6). Empty means missing.
class _NumInput extends StatefulWidget {
  const _NumInput({this.field, this.initial, required this.onChanged, this.decimal = false});
  final Field<num>? field;
  final String? initial;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  State<_NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<_NumInput> {
  late final _c = TextEditingController(
      text: widget.initial ?? (widget.field?.value == null ? '' : num1(widget.field!.value!)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(widget.decimal ? r'^\d{0,3}(\.\d?)?' : r'^\d{0,3}')),
      ],
      style: T.mono(17),
      onChanged: widget.onChanged,
    );
  }
}
