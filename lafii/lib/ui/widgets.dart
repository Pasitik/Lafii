import 'package:flutter/material.dart';
import 'package:visit_schema/visit_schema.dart';

import '../data/app_state.dart';
import '../theme.dart';

/// Page skeleton: status strip, optional header, scrollable body, bottom bar.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    this.header,
    required this.body,
    this.bottom,
    this.scroll = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(Sp.page, 0, Sp.page, 20),
  });

  final Widget? header;
  final Widget body;
  final Widget? bottom;
  final bool scroll;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: bodyPadding, child: body);
    return Scaffold(
      backgroundColor: C.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StatusStrip(),
            ?header,
            Expanded(
              child: scroll ? SingleChildScrollView(child: content) : content,
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Top strip: local save state, or receive mode. Never implies a network call.
class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final receive = s.isReceiveMode;
    final n = s.pendingSyncCount;
    final text = receive
        ? 'Receive mode · ${s.officer?.facility ?? ''}'
        : n == 0
            ? 'Saved on this phone'
            : '$n record${n == 1 ? '' : 's'} waiting to sync';
    return Container(
      height: 40,
      color: receive ? C.navy : C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      child: Text(text,
          style: T.ui(12, w: FontWeight.w600, color: receive ? C.surface : C.navy)),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    this.context_,
    required this.title,
    this.sub,
    this.trailing,
    this.divider = false,
    this.eyebrow,
  });

  final String? context_;
  final String title;
  final Widget? sub;
  final Widget? trailing;
  final bool divider;
  final Widget? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.page, 8, Sp.page, 12),
      margin: EdgeInsets.only(bottom: divider ? 12 : 0),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: C.border)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[eyebrow!, const SizedBox(height: 4)],
                if (context_ != null) Text(context_!, style: T.ui(14)),
                Text(title, style: T.display(22)),
                if (sub != null) ...[const SizedBox(height: 4), sub!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.children, this.note});

  /// Buttons laid out side by side. Use [Expanded] or [Flexible] for ratios.
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.page, 12, Sp.page, 20),
      decoration: const BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: _gap(children)),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: T.ui(12, height: 1.4)),
          ],
        ],
      ),
    );
  }

  static List<Widget> _gap(List<Widget> c) => [
        for (var i = 0; i < c.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          c[i] is Expanded || c[i] is Flexible ? c[i] : Expanded(child: c[i]),
        ]
      ];
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onPressed, this.height = 52});
  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sp.radius))),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return C.input;
            if (s.contains(WidgetState.pressed)) return C.navyPressed;
            return C.navy;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled) ? C.muted : C.surface),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(T.ui(15, w: FontWeight.w600)),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label,
      {super.key, this.onPressed, this.height = 52, this.fontSize = 15});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sp.radius))),
          side: const WidgetStatePropertyAll(BorderSide(color: C.input)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.pressed) ? C.pressed : Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(C.navy),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(T.ui(fontSize, w: FontWeight.w600)),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.caption});
  final String label;
  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: T.label),
        const SizedBox(height: 6),
        child,
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(caption!, style: T.ui(13)),
        ],
      ],
    );
  }
}

/// Read-only box that looks like an input.
class ValueBox extends StatelessWidget {
  const ValueBox(this.text, {super.key, this.onTap, this.style});
  final String text;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Sp.radius),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: C.card,
          border: Border.all(color: C.input),
          borderRadius: BorderRadius.circular(Sp.radius),
        ),
        child: Text(text, style: style ?? T.ui(16, w: FontWeight.w500, color: C.strong)),
      ),
    );
  }
}

/// White card with hairline border and row dividers. No shadow.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border.all(color: C.border),
        borderRadius: BorderRadius.circular(Sp.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: C.divider),
            children[i],
          ]
        ],
      ),
    );
  }
}

class KvRow extends StatelessWidget {
  const KvRow(this.k, this.v, {super.key, this.valueColor, this.mono = false});
  final String k;
  final String v;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: T.ui(14))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: mono
                    ? T.mono(15, w: FontWeight.w600, color: valueColor ?? C.strong)
                    : T.ui(14, w: FontWeight.w600, color: valueColor ?? C.strong)),
          ),
        ],
      ),
    );
  }
}

class PlainRow extends StatelessWidget {
  const PlainRow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(text, style: T.ui(16, w: FontWeight.w500, color: C.strong)),
      );
}

enum CalloutKind { neutral, info, success }

class Callout extends StatelessWidget {
  const Callout({super.key, required this.title, this.body, this.kind = CalloutKind.neutral});
  final String title;
  final String? body;
  final CalloutKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      CalloutKind.neutral => (C.card, C.navy),
      CalloutKind.info => (C.infoTint, C.navy),
      CalloutKind.success => (C.greenTint, C.greenDeep),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: C.border),
        borderRadius: BorderRadius.circular(Sp.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.ui(14, w: FontWeight.w600, color: fg)),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(body!, style: T.ui(14, color: C.bodyStrong, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.size = 16});
  final String text;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
              child: Text(text, style: T.ui(size, w: FontWeight.w600, color: C.navy))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Full-width segmented control. Tapping the selected option clears it when
/// [allowClear] is set, so an answer can return to "not recorded".
class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
    this.fontSize = 15,
  });

  final List<(V, String)> options;
  final V? value;
  final ValueChanged<V?> onChanged;
  final bool allowClear;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: C.input),
        borderRadius: BorderRadius.circular(Sp.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++)
              Expanded(
                child: _cell(options[i], i > 0),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell((V, String) o, bool leftBorder) {
    final sel = o.$1 == value;
    return Material(
      color: sel ? C.navy : C.card,
      child: InkWell(
        onTap: () => onChanged(sel && allowClear ? null : o.$1),
        child: Container(
          constraints: const BoxConstraints(minHeight: Sp.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: leftBorder ? const Border(left: BorderSide(color: C.input)) : null,
          ),
          child: Text(o.$2,
              textAlign: TextAlign.center,
              style: T.ui(fontSize, w: FontWeight.w600, color: sel ? C.surface : C.navy)),
        ),
      ),
    );
  }
}

/// Status is a 3px left edge rule plus a plain word, never a capsule.
class UrgencyEdge extends StatelessWidget {
  const UrgencyEdge({super.key, required this.urgency, required this.child});
  final Urgency? urgency;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: urgency == null ? Colors.transparent : C.urgency(urgency!), width: 3),
        ),
      ),
      child: child,
    );
  }
}

String urgencyWord(Urgency u) => switch (u) {
      Urgency.emergency => 'Emergency',
      Urgency.urgent => 'Urgent',
      Urgency.routine => 'Routine',
    };

/// Tappable row with a chevron, the only icon allowed.
class ChevronRow extends StatelessWidget {
  const ChevronRow({super.key, required this.title, this.meta, required this.onTap});
  final String title;
  final String? meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: T.ui(15, w: FontWeight.w600, color: C.strong)),
                  if (meta != null) Text(meta!, style: T.ui(13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: C.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Dashed outline used for anything still waiting on the officer.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.width = 1,
    this.color = C.dashed,
    this.fill = C.surface,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final double width;
  final Color color;
  final Color fill;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(width, color, fill),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.w, this.color, this.fill);
  final double w;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
        Offset(w / 2, w / 2) & Size(size.width - w, size.height - w),
        const Radius.circular(Sp.radius));
    canvas.drawRRect(rect, Paint()..color = fill);
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    const dash = 5.0, gap = 4.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.w != w || old.color != color || old.fill != fill;
}

/// Yes / No pair for one danger sign. Untouched is visibly neither.
class TriStateRow extends StatelessWidget {
  const TriStateRow({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final TriState value;
  final ValueChanged<TriState> onChanged;

  @override
  Widget build(BuildContext context) {
    final caption = switch (value) {
      TriState.yes => 'Yes',
      TriState.no => 'No',
      TriState.notAsked => 'Not asked',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.divider))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.ui(15, w: FontWeight.w500, color: C.strong)),
                Text(caption, style: T.ui(12, color: C.muted)),
              ],
            ),
          ),
          _btn('Yes', TriState.yes),
          const SizedBox(width: 10),
          _btn('No', TriState.no),
        ],
      ),
    );
  }

  Widget _btn(String text, TriState v) {
    final sel = value == v;
    final caption = Text(text,
        style: T.ui(14, w: FontWeight.w600, color: sel ? C.surface : C.navy));
    return Semantics(
      button: true,
      selected: sel,
      label: '$label $text',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(sel ? TriState.notAsked : v),
        child: SizedBox(
          width: 60,
          height: Sp.minTarget,
          child: sel
              ? Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: C.navy, borderRadius: BorderRadius.circular(Sp.radius)),
                  child: caption)
              : DashedBox(child: Center(child: caption)),
        ),
      ),
    );
  }
}

/// Screen shown when a scan or lookup cannot continue. Plain words only.
class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      header: ScreenHeader(title: title),
      body: Text(body, style: T.bodyText),
      bottom: BottomBar(children: [
        PrimaryButton('Back', onPressed: () => Navigator.pop(context)),
      ]),
    );
  }
}
