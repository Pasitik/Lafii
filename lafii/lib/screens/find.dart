import 'dart:math';

import 'package:card_codec/card_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resolver/resolver.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../ui/widgets.dart';
import 'visit.dart';

/// 03 Find a woman, and 15 No match. The register action stays in the same
/// place and style in every state (1.4).
class FindScreen extends StatefulWidget {
  const FindScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  late final _q = TextEditingController(text: widget.initialQuery);

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _choose(Patient p) {
    final s = AppScope.read(context);
    final dupes = s.duplicatesOf(p);
    final next = dupes.isEmpty
        ? VisitScreen(visit: s.startVisit(p))
        : DuplicateScreen(patients: [p, dupes.first]);
    Navigator.push(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final query = _q.text.trim();
    final results = search(query, s.candidates);
    final helper = query.isEmpty
        ? 'Type part of her name. Check community, age and last contact before you choose.'
        : results.isEmpty
            ? 'No records match. Try another spelling, or register her below.'
            : '${results.length} record${results.length == 1 ? '' : 's'} match. '
                'Check community, age and last contact before you choose.';

    return AppScreen(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Find a woman', style: T.display(22)),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: T.ui(16, color: C.strong),
            ),
            const SizedBox(height: 12),
            Text(helper, style: T.ui(14, height: 1.4)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in results) ...[
            _CandidateCard(c, s.now, onTap: () => _choose(c.patient)),
            const SizedBox(height: 8),
          ],
        ],
      ),
      bottom: BottomBar(children: [
        SecondaryButton('Register a new woman',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RegisterScreen(initialName: query)))),
      ]),
    );
  }
}

/// No score, no highlight. Evidence only: community, age, last contact.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard(this.c, this.now, {required this.onTap});
  final Candidate c;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = c.patient;
    final age = p.ageAt(now);
    return Material(
      color: C.card,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: C.border),
          borderRadius: BorderRadius.circular(Sp.radius)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sp.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                    child: Text(p.fullName,
                        style: T.ui(16, w: FontWeight.w600, color: C.strong))),
                Text(age == null ? 'Age not recorded' : 'Age $age', style: T.ui(14)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text(p.community, style: T.ui(14))),
                Text(
                    c.lastContact == null
                        ? 'Not seen yet'
                        : 'Last seen ${dayMonthYear(c.lastContact!)}',
                    style: T.ui(14)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 04 Possible duplicate. Equal weight, no preselection, order randomised
/// per session (1.5). Nothing is merged.
class DuplicateScreen extends StatelessWidget {
  DuplicateScreen({super.key, required List<Patient> patients})
      : patients = [...patients]..shuffle(_sessionRandom);
  final List<Patient> patients;

  static final _sessionRandom = Random();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return AppScreen(
      header: ScreenHeader(
        title: 'These may be the same woman',
        sub: Text('Ask her and compare. Nothing will be merged unless you choose.',
            style: T.bodyText),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < patients.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _DupCard(patients[i], s)),
          ],
        ],
      ),
      bottom: BottomBar(children: [
        SecondaryButton('Register a new woman',
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const RegisterScreen()))),
      ]),
    );
  }
}

class _DupCard extends StatelessWidget {
  const _DupCard(this.p, this.s);
  final Patient p;
  final AppState s;

  String get _phone {
    final ph = p.phone;
    if (ph == null || ph.length < 7) return 'Not recorded';
    return '${ph.substring(0, 3)} ••• ${ph.substring(ph.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final last = s.lastContact(p.id);
    Widget pair(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: T.ui(12, color: C.muted)),
            Text(v, style: T.ui(14, w: FontWeight.w500, color: C.strong)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: C.card,
        border: Border.all(color: C.input),
        borderRadius: BorderRadius.circular(Sp.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.fullName, style: T.ui(16, w: FontWeight.w600, color: C.strong, height: 1.3)),
          const SizedBox(height: 10),
          pair('Age', p.ageAt(s.now)?.toString() ?? 'Not recorded'),
          pair('Community', p.community),
          pair('Last contact', last == null ? 'None' : dayMonthYear(last)),
          pair('Visits', '${s.visitsFor(p.id).length}'),
          pair('Phone', _phone),
          SecondaryButton('This is her',
              height: Sp.minTarget,
              fontSize: 14,
              onPressed: () {
                final visit = s.startVisit(p);
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => VisitScreen(visit: visit)));
              }),
        ],
      ),
    );
  }
}

/// Register a new woman. Not in the handoff; built from the same parts.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialName = '',
    this.community,
    this.age,
    this.weeks,
    this.gravida,
    this.para,
  });
  final String initialName;

  /// Prefilled from a card read on this phone. All remain editable.
  final String? community;
  final int? age;
  final int? weeks;
  final int? gravida;
  final int? para;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final _given = TextEditingController();
  late final _family = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _weeks = TextEditingController();
  final _gravida = TextEditingController();
  final _para = TextEditingController();
  String? _community;

  @override
  void initState() {
    super.initState();
    final words = widget.initialName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty) _given.text = words.first;
    if (words.length > 1) _family.text = words.sublist(1).join(' ');
    _community = widget.community;
    if (widget.age != null) _age.text = '${widget.age}';
    if (widget.weeks != null) _weeks.text = '${widget.weeks}';
    if (widget.gravida != null) _gravida.text = '${widget.gravida}';
    if (widget.para != null) _para.text = '${widget.para}';
    for (final c in [_given, _family, _age, _weeks, _gravida, _para]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_given, _family, _age, _phone, _weeks, _gravida, _para]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Required fields not yet filled, in form order.
  List<String> get _stillNeeded => [
        if (_given.text.trim().isEmpty) 'given name',
        if (_family.text.trim().isEmpty) 'family name',
        if (_community == null) 'community',
        if (int.tryParse(_weeks.text) == null) 'weeks pregnant',
        if (int.tryParse(_gravida.text) == null) 'gravida',
        if (int.tryParse(_para.text) == null) 'para',
      ];

  bool get _complete => _stillNeeded.isEmpty;

  static const _another = '\u0000another';

  Future<String?> _typeCommunity() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Her community', style: T.display(20)),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: T.ui(16, color: C.strong),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()),
              child: const Text('Use this')),
        ],
      ),
    );
  }

  Future<void> _pickCommunity() async {
    // Otherwise the keyboard reopens on the last text field when the sheet closes.
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.card,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final c in communityCodes.values)
            InkWell(
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: Sp.page),
                alignment: Alignment.centerLeft,
                child: Text(c, style: T.ui(16, color: C.strong)),
              ),
            ),
          InkWell(
            onTap: () => Navigator.pop(ctx, _another),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: Sp.page),
              alignment: Alignment.centerLeft,
              child: Text('Another community', style: T.ui(16, w: FontWeight.w600, color: C.navy)),
            ),
          ),
        ]),
      ),
    );
    if (picked == _another) {
      final typed = await _typeCommunity();
      if (typed != null) setState(() => _community = typed);
    } else if (picked != null) {
      setState(() => _community = picked);
    }
  }

  void _save() {
    final s = AppScope.read(context);
    final age = int.tryParse(_age.text);
    final p = s.registerPatient(
      givenName: _given.text.trim(),
      familyName: _family.text.trim(),
      community: _community!,
      birthYear: age == null ? null : s.now.year - age,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      gestationalWeeks: int.parse(_weeks.text),
      gravida: int.parse(_gravida.text),
      para: int.parse(_para.text),
    );
    final visit = s.startVisit(p);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VisitScreen(visit: visit)));
  }

  Widget _num(String label, TextEditingController c) => LabeledField(
        label: label,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: T.mono(17),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);
    return AppScreen(
      header: const ScreenHeader(title: 'Register a new woman', divider: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
              label: 'Given name',
              child: TextField(
                  controller: _given,
                  textCapitalization: TextCapitalization.words,
                  style: T.ui(16, color: C.strong))),
          gap,
          LabeledField(
              label: 'Family name',
              child: TextField(
                  controller: _family,
                  textCapitalization: TextCapitalization.words,
                  style: T.ui(16, color: C.strong))),
          gap,
          LabeledField(
            label: 'Community',
            child: ValueBox(_community ?? 'Choose her community',
                onTap: _pickCommunity,
                style: T.ui(16, color: _community == null ? C.muted : C.strong)),
          ),
          gap,
          Row(children: [
            Expanded(child: _num('Age', _age)),
            const SizedBox(width: 10),
            Expanded(child: _num('Weeks pregnant', _weeks)),
          ]),
          gap,
          Row(children: [
            Expanded(child: _num('Gravida', _gravida)),
            const SizedBox(width: 10),
            Expanded(child: _num('Para', _para)),
          ]),
          const SizedBox(height: 6),
          Text('Gravida: pregnancies including this one. Para: births. '
              'For a first pregnancy enter 1 and 0.',
              style: T.ui(13, height: 1.4)),
          gap,
          LabeledField(
            label: 'Phone',
            caption: 'Leave blank if she has none',
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: T.mono(17),
            ),
          ),
        ],
      ),
      bottom: BottomBar(
        note: _complete ? null : 'Still needed: ${_stillNeeded.join(', ')}.',
        children: [
          PrimaryButton('Register and start visit', onPressed: _complete ? _save : null),
        ],
      ),
    );
  }
}
