import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/history.dart';
import '../../core/printer_service.dart';
import '../../core/settings.dart';
import '../flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'note_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final printer = context.watch<PrinterService>();
    final st = context.watch<AppSettings>();
    final recent = context.watch<HistoryStore>().items.take(3).toList();
    final name = st.lastName.isEmpty ? 'No printer selected' : st.lastName;
    final sub = printer.connected
        ? '${st.paperMm} mm · ready'
        : (st.lastMac.isEmpty ? 'Tap to choose your printer' : 'Tap to reconnect');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Row(children: [
              Text('Parchi', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.ink, letterSpacing: -0.8)),
              const SizedBox(width: 8),
              Text('پرچی', style: TextStyle(fontSize: 22, color: p.acc, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Pill('No watermark', tone: Tone.ok),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => shellTab.value = 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: p.bg.withAlpha(40), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.print, color: p.bg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.bg)),
                      Text(sub, style: TextStyle(fontSize: 13, color: p.bg.withAlpha(180))),
                    ]),
                  ),
                  Pill(printer.connected ? 'Connected' : 'Offline', tone: printer.connected ? Tone.ok : Tone.bad, dot: true),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
              children: [
                _Act(Icons.picture_as_pdf_outlined, Tone.acc, 'Choose PDF', 'From Files or Drive', () => pickAndOpen(pdf: true)),
                _Act(Icons.image_outlined, Tone.ok, 'Choose image', 'Logo, photo, scan', () => pickAndOpen(pdf: false)),
                _Act(Icons.edit_note, Tone.warn, 'Type a note', 'Text, any language', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NoteScreen()))),
                _Act(Icons.content_paste, Tone.neutral, 'Paste text', 'From clipboard', pasteText),
              ],
            ),
            const SizedBox(height: 14),
            PCard(
              color: p.accTint,
              onTap: () => toast('In WhatsApp, Gmail or Files: tap Share, then choose Parchi.'),
              child: Row(children: [
                IconBadge(Icons.share_outlined, tone: Tone.acc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fastest way: share to Parchi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    Text('Share a PDF from any app, then tap Print now.', style: TextStyle(color: p.mute, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            if (recent.isNotEmpty) ...[
              Row(children: [
                const Expanded(child: SectionLabel('Recent prints')),
                TextButton(onPressed: () => shellTab.value = 2, child: const Text('See all')),
              ]),
              ListGroup(children: [
                for (final e in recent)
                  Tile(
                    leading: IconBadge(kindIcon(e.kind), tone: e.ok ? Tone.acc : Tone.bad),
                    title: e.title,
                    subtitle: '${dayLabel(e.at)} · ${clockText(e.at)}${e.ok ? '' : ' · failed'}',
                    trailing: PButton('Print', small: true, expand: false, kind: BKind.ghost, onTap: () => reprint(e)),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act(this.icon, this.tone, this.title, this.sub, this.onTap);
  final IconData icon;
  final Tone tone;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, tone: tone),
        const Spacer(),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(sub, style: TextStyle(color: p.mute, fontSize: 12.5)),
      ]),
    );
  }
}
