import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'theme.dart';

IconData kindIcon(JobKind k) {
  switch (k) {
    case JobKind.pdf: return Icons.picture_as_pdf_outlined;
    case JobKind.image: return Icons.image_outlined;
    case JobKind.receipt: return Icons.receipt_long_outlined;
    case JobKind.text: return Icons.notes;
    case JobKind.qr: return Icons.qr_code_2;
    case JobKind.barcode: return Icons.view_week_outlined;
    case JobKind.test: return Icons.build_outlined;
  }
}

class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: color ?? p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.tone = Tone.acc, this.size = 44});
  final IconData icon;
  final Tone tone;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: p.toneBg(tone), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, color: p.toneFg(tone), size: size * 0.5),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.acc, this.dot = false});
  final String text;
  final Tone tone;
  final bool dot;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = p.toneFg(tone == Tone.neutral ? Tone.acc : tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: p.toneBg(tone == Tone.neutral ? Tone.acc : tone), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Text(text, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

enum BKind { primary, ghost, danger }

class PButton extends StatelessWidget {
  const PButton(this.label, {super.key, this.onTap, this.icon, this.kind = BKind.primary, this.small = false, this.expand = true});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final BKind kind;
  final bool small;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Color bg, fg;
    switch (kind) {
      case BKind.primary: bg = p.acc; fg = p.accInk; break;
      case BKind.ghost: bg = p.card; fg = p.ink; break;
      case BKind.danger: bg = p.badTint; fg = p.bad; break;
    }
    final r = BorderRadius.circular(small ? 12 : 16);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: SizedBox(
        height: small ? 40 : 52,
        width: expand ? double.infinity : null,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(borderRadius: r, side: kind == BKind.ghost ? BorderSide(color: p.line) : BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: small ? 16 : 20),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 14 : 16))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.value, required this.items, required this.onChanged});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
      child: Row(
        children: items.entries.map((e) {
          final sel = e.key == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: sel ? p.card : Colors.transparent, borderRadius: BorderRadius.circular(9),
                    boxShadow: sel ? [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 3, offset: const Offset(0, 1))] : null),
                child: Text(e.value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: sel ? p.ink : p.mute)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99});
  final int value, min, max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget b(IconData i, VoidCallback? f) => InkWell(
          onTap: f,
          customBorder: const CircleBorder(),
          child: Container(width: 34, height: 34, decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle, border: Border.all(color: p.line)), child: Icon(i, size: 18, color: f == null ? p.mute : p.ink)),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      b(Icons.remove, value > min ? () => onChanged(value - 1) : null),
      SizedBox(width: 36, child: Center(child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))),
      b(Icons.add, value < max ? () => onChanged(value + 1) : null),
    ]);
  }
}

class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, color: p.line));
      rows.add(children[i]);
    }
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class Tile extends StatelessWidget {
  const Tile({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap, this.titleColor});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: titleColor ?? p.ink)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(subtitle!, style: TextStyle(fontSize: 13, color: p.mute))),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({super.key, required this.title, this.subtitle, required this.value, required this.onChanged, this.leading});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  @override
  Widget build(BuildContext context) =>
      Tile(title: title, subtitle: subtitle, leading: leading, onTap: () => onChanged(!value), trailing: Switch(value: value, onChanged: onChanged));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

class Banner2 extends StatelessWidget {
  const Banner2(this.text, {super.key, this.tone = Tone.ok, this.icon = Icons.check_circle_outline});
  final String text;
  final Tone tone;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.toneBg(tone), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, size: 20, color: p.toneFg(tone)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: p.toneFg(tone), fontWeight: FontWeight.w700, fontSize: 13.5))),
      ]),
    );
  }
}

/// A strip of thermal paper with a torn bottom edge showing the real print.
class PaperPreview extends StatelessWidget {
  const PaperPreview({super.key, this.image, this.width = 248});
  final ui.Image? image;
  final double width;
  @override
  Widget build(BuildContext context) {
    final img = image;
    return SizedBox(
      width: width,
      child: PhysicalShape(
        clipper: _ZigClipper(),
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 18),
          child: img == null
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : AspectRatio(
                  aspectRatio: img.width / img.height,
                  child: RawImage(image: img, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                ),
        ),
      ),
    );
  }
}

class _ZigClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const t = 8.0;
    final n = (s.width / 12).floor().clamp(4, 80);
    final step = s.width / n;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height - t);
    for (var i = 0; i < n; i++) {
      path.lineTo(s.width - step * (i + 0.5), s.height);
      path.lineTo(s.width - step * (i + 1), s.height - t);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
