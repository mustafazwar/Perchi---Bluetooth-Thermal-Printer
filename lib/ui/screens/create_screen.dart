import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/history.dart';
import '../../core/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'builder_screen.dart';
import 'note_screen.dart';
import 'qr_screen.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final templates = context.watch<TemplateStore>().items;
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        Material(
          color: p.acc,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => go(const BuilderScreen()),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Icon(Icons.receipt_long, color: p.accInk, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Receipt builder', style: TextStyle(color: p.accInk, fontWeight: FontWeight.w800, fontSize: 17)),
                    Text('Bills with items, totals and your shop header', style: TextStyle(color: p.accInk.withAlpha(200), fontSize: 13)),
                  ]),
                ),
                Icon(Icons.chevron_right, color: p.accInk),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.45,
          children: [
            _Tile(Icons.edit_note, Tone.acc, 'Text note', 'Any language', () => go(const NoteScreen())),
            _Tile(Icons.qr_code_2, Tone.ok, 'QR code', 'Link, phone, text', () => go(const QrScreen())),
            _Tile(Icons.view_week_outlined, Tone.warn, 'Barcode', 'Code 128, EAN-13', () => go(const QrScreen(barcode: true))),
          ],
        ),
        const SectionLabel('Saved templates'),
        if (templates.isEmpty)
          PCard(child: Text('Build a receipt and tap Save to keep it here for next time.', style: TextStyle(color: p.mute)))
        else
          ListGroup(children: [
            for (final t in templates)
              Dismissible(
                key: ValueKey(t['name']),
                direction: DismissDirection.endToStart,
                background: Container(color: p.badTint, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Icon(Icons.delete_outline, color: p.bad)),
                onDismissed: (_) => context.read<TemplateStore>().remove(t['name'] as String),
                child: Container(
                  color: p.card,
                  child: Tile(
                    leading: const IconBadge(Icons.receipt_long_outlined),
                    title: t['name'] as String,
                    subtitle: 'Swipe left to delete',
                    trailing: Icon(Icons.chevron_right, color: p.mute),
                    onTap: () => go(BuilderScreen(
                      initial: ReceiptData.fromJson(Map<String, dynamic>.from(t['data'] as Map)),
                      templateName: t['name'] as String,
                    )),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.tone, this.title, this.sub, this.onTap);
  final IconData icon;
  final Tone tone;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, tone: tone, size: 40),
        const Spacer(),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Text(sub, style: TextStyle(color: p.mute, fontSize: 12.5)),
      ]),
    );
  }
}
