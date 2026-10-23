import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'outcome.dart';

/// 07 Confirm each value (3.1 to 3.3, 3.6).
///
/// One tap per value. There is deliberately no confirm-all (invariant 1).
/// Values typed on screen 05 arrive as manual and already count; anything
/// extracted from speech arrives dashed and counts only once confirmed.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen(
      {super.key,
      required this.visit,
      this.spoken = false,
      this.notes = const [],
      this.heard,
      this.unrecognised = 0,
      this.peakDb = -120});

  /// Loudest microphone input, for telling a dead microphone from a quiet room.
  final double peakDb;

  /// Words heard but not matched to the vocabulary.
  final int unrecognised;

  /// What the recogniser returned, shown on this screen only. Never stored.
  final String? heard;
  final AncVisit visit;

  /// Reached from the recording screen rather than from tap entry.
  final bool spoken;

  /// What was heard but not used: contradictions, out of range readings.
  final List<String> notes;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

const _measureOrder = [
  Measure.systolic,
  Measure.diastolic,
  Measure.temperatureC,
  Measure.weightKg,
  Measure.pulse,
  Measure.fundalHeightCm,
  Measure.fetalHeartRate,
  Measure.urineProtein,
  Measure.haemoglobin,
];

class _ConfirmScreenState extends State<ConfirmScreen> {
  AncVisit get v => widget.visit;
  late final AppState s = AppScope.read(context);

  void _changed() {
    setState(() {});
    s.saveVisit(v);
  }

  String _show(Measure m, num value) => switch (m) {
        Measure.urineProtein => value == 0 ? 'Nil' : '${value.round()}+',
        _ => '${num1(value)} ${m.unit}',
      };

  Future<void> _editMeasure(Measure m) async {
    final current = v.measure(m).value;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => _NumberDialog(
          title: m.label, unit: m.unit, initial: current == null ? '' : num1(current), decimal: m.isDecimal),
    );
    if (text == null) return;
    v.setMeasure(m, num.tryParse(text));
    _changed();
  }

  Future<void> _editWeeks(Pregnancy g) async {
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => _NumberDialog(
          title: 'Weeks pregnant', unit: 'weeks', initial: '${g.gestationalWeeks}'),
    );
    final w = int.tryParse(text ?? '');
    if (w == null) return;
    g.gestationalWeeks = w;
    s.putPregnancy(g);
    setState(() {});
  }

  Future<void> _editSign(DangerSign sign) async {
    final picked = await showDialog<TriState>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(sign.label, style: T.display(20)),
        children: [
          for (final (t, l) in const [
            (TriState.yes, 'Yes'),
            (TriState.no, 'No'),
            (TriState.notAsked, 'Not asked'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(l, style: T.ui(16, color: C.strong)),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    v.sign(sign).setManual(picked == TriState.notAsked ? null : picked);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final g = s.pregnancies[v.pregnancyId]!;

    final rows = <_Row>[];
    for (final m in _measureOrder) {
      final f = v.measure(m);
      rows.add(_Row(
        label: m.label,
        value: f.value == null ? null : _show(m, f.value!),
        field: f,
        onEdit: () => _editMeasure(m),
        onToggle: () {
          f.usableByRules ? f.unconfirm() : f.confirm();
          _changed();
        },
      ));
      if (m == Measure.diastolic) {
        rows.add(_Row(
          label: 'Weeks pregnant',
          value: '${g.gestationalWeeks}',
          onEdit: () => _editWeeks(g),
        ));
      }
    }
    for (final sign in DangerSign.values) {
      final f = v.sign(sign);
      if (f.value == null || f.value == TriState.notAsked) continue;
      rows.add(_Row(
        label: sign.label,
        value: f.value == TriState.yes ? 'Yes' : 'No',
        field: f,
        onEdit: () => _editSign(sign),
        onToggle: () {
          f.usableByRules ? f.unconfirm() : f.confirm();
          _changed();
        },
      ));
    }

    final present = rows.where((r) => r.value != null && r.field != null).toList();
    final waiting = present.where((r) => !r.field!.usableByRules).length;
    final missing = rows.where((r) => r.value == null).length;
    final sub = waiting == 0
        ? 'All values confirmed · $missing missing'
        : '$waiting of ${present.length} values still need you · $missing missing';

    return AppScreen(
      header: ScreenHeader(
        title: widget.spoken ? 'Check what you said' : 'Check what you recorded',
        divider: true,
        sub: Text(sub, style: T.ui(14, w: FontWeight.w500, color: C.strong)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.heard != null) ...[
            Callout(
              title: 'What the phone heard',
              body: [
                if (widget.heard!.trim().isNotEmpty) widget.heard!.trim(),
                if (widget.heard!.trim().isEmpty && widget.unrecognised == 0)
                  'Silence. The microphone picked up no speech '
                      '(loudest sound ${widget.peakDb.round()} dB).',
                if (widget.unrecognised > 0)
                  '${widget.unrecognised} word${widget.unrecognised == 1 ? '' : 's'} '
                      'heard but not recognised.',
              ].join('\n'),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.notes.isNotEmpty) ...[
            Callout(title: 'Heard but not used', body: widget.notes.join('\n')),
            const SizedBox(height: 12),
          ],
          for (final r in rows) ...[r, const SizedBox(height: 8)],
        ],
      ),
      bottom: BottomBar(
        note: 'Unconfirmed values are left out of the assessment',
        children: [
          PrimaryButton('Continue to assessment', onPressed: () {
            final o = s.assess(v);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => o.assessment.urgency == Urgency.routine
                        ? RoutineScreen(visit: v)
                        : AssessmentScreen(visit: v)));
          }),
        ],
      ),
    );
  }
}

/// One value. Unconfirmed is dashed and grey, confirmed is solid, missing
/// says Missing in red and offers Enter.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.field, required this.onEdit, this.onToggle});
  final String label;
  final String? value;
  final Field<Object>? field;
  final VoidCallback onEdit;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final missing = value == null;
    final confirmed = field == null || field!.usableByRules;

    final Widget action;
    if (missing) {
      action = SecondaryButton('Enter', height: Sp.minTarget, fontSize: 14, onPressed: onEdit);
    } else if (!confirmed) {
      action = PrimaryButton('Confirm', height: Sp.minTarget, onPressed: onToggle);
    } else {
      action = SizedBox(
        height: Sp.minTarget,
        child: TextButton(
          onPressed: onToggle,
          style: TextButton.styleFrom(
            backgroundColor: C.greenTint,
            foregroundColor: C.greenDeep,
            disabledForegroundColor: C.greenDeep,
            overlayColor: Colors.transparent,
            textStyle: T.ui(14, w: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: C.greenBg),
                borderRadius: BorderRadius.circular(Sp.radius)),
          ),
          child: const Text('Confirmed'),
        ),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: T.ui(12, color: C.muted)),
                  Text(
                    value ?? 'Missing',
                    style: T.ui(17,
                        w: FontWeight.w600,
                        color: missing ? C.red : (confirmed ? C.strong : C.muted)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 92), child: action),
        ],
      ),
    );

    if (!missing && !confirmed) {
      return DashedBox(width: 2, child: content);
    }
    return Container(
      decoration: BoxDecoration(
        color: missing ? C.surface : C.card,
        border: Border.all(color: C.border),
        borderRadius: BorderRadius.circular(Sp.radius),
      ),
      child: content,
    );
  }
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({required this.title, required this.unit, required this.initial, this.decimal = false});
  final String title;
  final String unit;
  final String initial;
  final bool decimal;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: T.display(20)),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(widget.decimal ? r'^\d{0,3}(\.\d?)?' : r'^\d{0,3}')),
        ],
        style: T.mono(20),
        decoration: InputDecoration(suffixText: widget.unit, suffixStyle: T.ui(14)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Save')),
      ],
    );
  }
}
