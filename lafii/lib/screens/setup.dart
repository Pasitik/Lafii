import 'package:card_codec/card_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';

import '../data/app_state.dart';
import '../data/seed.dart';
import '../theme.dart';
import '../ui/widgets.dart';

/// Load the demo records on first setup in refer mode.
const kSeedDemoData = true;

/// 01 Setup. Shown once on first launch, and again from Settings.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  AppMode _mode = AppMode.refer;
  final _name = TextEditingController();
  final _zone = TextEditingController();
  final _phone = TextEditingController();
  String? _facility;

  @override
  void initState() {
    super.initState();
    final o = AppScope.read(context).officer;
    if (o != null) {
      _mode = o.mode;
      _name.text = o.name;
      _zone.text = o.zone;
      _facility = o.facility;
      _phone.text = o.phone ?? '';
    }
    for (final c in [_name, _zone, _phone]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _zone.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _complete =>
      _name.text.trim().isNotEmpty &&
      _zone.text.trim().isNotEmpty &&
      _facility != null &&
      cleanPhone(_phone.text) != null;

  Future<void> _pickFacility() async {
    // Otherwise the keyboard reopens on the last text field when the sheet closes.
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Sp.radius))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final f in facilityCodes.values)
              InkWell(
                onTap: () => Navigator.pop(ctx, f),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.page),
                  alignment: Alignment.centerLeft,
                  child: Text(f,
                      style: T.ui(16,
                          w: f == _facility ? FontWeight.w600 : FontWeight.w400,
                          color: C.strong)),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _facility = picked);
  }

  void _save() {
    final s = AppScope.read(context);
    final first = !s.isSetUp;
    s.saveOfficer(Officer(
      name: _name.text.trim(),
      zone: _zone.text.trim(),
      facility: _facility!,
      mode: _mode,
      phone: cleanPhone(_phone.text),
    ));
    if (first && kSeedDemoData && _mode == AppMode.refer && s.patients.isEmpty) {
      seedDemo(s);
    }
    if (widget.editing) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      bodyPadding: const EdgeInsets.fromLTRB(Sp.page, 24, Sp.page, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.editing ? 'Settings' : 'Set up this phone', style: T.display(26)),
          const SizedBox(height: 6),
          Text(
            'You do this once. Your name goes on every referral you issue. '
            'No account or login is needed.',
            style: T.bodyText,
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'This phone is used to',
            child: Segmented<AppMode>(
              options: const [
                (AppMode.refer, 'Refer patients'),
                (AppMode.receive, 'Receive patients'),
              ],
              value: _mode,
              onChanged: (m) => setState(() {
                _mode = m ?? _mode;
                if (_mode == AppMode.receive && _facility == null) {
                  _facility = kReferralDestination;
                }
              }),
            ),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'Your name',
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              style: T.ui(16, color: C.strong),
            ),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: _mode == AppMode.refer ? 'CHPS zone' : 'Ward or unit',
            child: TextField(
              controller: _zone,
              textCapitalization: TextCapitalization.words,
              style: T.ui(16, color: C.strong),
            ),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'Your phone number',
            caption: _mode == AppMode.refer
                ? 'Printed on each referral card so the hospital can call you.'
                : 'Printed on each acknowledgement so the referring officer can call you.',
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              style: T.mono(17),
            ),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'Facility',
            child: ValueBox(_facility ?? 'Choose your facility',
                onTap: _pickFacility,
                style: T.ui(16, color: _facility == null ? C.muted : C.strong)),
          ),
        ],
      ),
      bottom: BottomBar(children: [
        PrimaryButton(widget.editing ? 'Save settings' : 'Start using the app',
            onPressed: _complete ? _save : null),
      ]),
    );
  }
}
