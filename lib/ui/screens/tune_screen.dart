import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/print_session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'printing_screen.dart';

class TuneScreen extends StatelessWidget {
  const TuneScreen({super.key, required this.session});
  final PrintSession session;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('Print settings')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: PButton('Print', icon: Icons.print, onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PrintingScreen(session: session)))),
        ),
      ),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final o = session.opts;
          Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: TextStyle(color: p.mute, fontWeight: FontWeight.w700, fontSize: 13)));
          return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 18), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  label('Paper width'),
                  Seg<int>(value: o.paperMm, items: const {58: '58 mm', 80: '80 mm'}, onChanged: (v) => session.update((o) => o.paperMm = v)),
                  const SizedBox(height: 16),
                  label('Image style'),
                  Seg<ImageStyle>(
                    value: o.style,
                    items: const {ImageStyle.text: 'Text', ImageStyle.photo: 'Photo', ImageStyle.halftone: 'Dots'},
                    onChanged: (v) => session.update((o) => o.style = v),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: label('Darkness')),
                    Text('${o.darkness}%', style: TextStyle(color: p.mute, fontWeight: FontWeight.w600)),
                  ]),
                  Slider(
                    value: o.darkness.toDouble(), min: 0, max: 100, divisions: 20,
                    onChanged: (v) => session.tweak((o) => o.darkness = v.round()),
                    onChangeEnd: (_) => session.refresh(),
                  ),
                  label('Copies'),
                  QtyStepper(value: o.copies, max: 20, onChanged: (v) => session.tweak((o) => o.copies = v)),
                ]),
              ),
              const SizedBox(width: 12),
              Container(
                width: 140, height: 380,
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(child: Center(child: PaperPreview(image: session.preview, width: 118))),
              ),
            ]),
            const SizedBox(height: 18),
            ListGroup(children: [
              SwitchTile(
                leading: const IconBadge(Icons.content_cut, tone: Tone.ok, size: 38),
                title: 'Trim blank space', subtitle: 'Cuts empty margins top and bottom',
                value: o.trim, onChanged: (v) => session.update((o) => o.trim = v),
              ),
              SwitchTile(
                leading: const IconBadge(Icons.layers_outlined, size: 38),
                title: 'Stitch pages into one roll', subtitle: 'No tear gap between PDF pages',
                value: o.stitch, onChanged: (v) => session.update((o) => o.stitch = v),
              ),
              SwitchTile(
                leading: const IconBadge(Icons.invert_colors, tone: Tone.warn, size: 38),
                title: 'Invert black and white', subtitle: 'For light text on dark images',
                value: o.invert, onChanged: (v) => session.update((o) => o.invert = v),
              ),
              SwitchTile(
                leading: const IconBadge(Icons.cut, tone: Tone.neutral, size: 38),
                title: 'Auto-cut after print', subtitle: 'Only if your printer has a cutter',
                value: o.autoCut, onChanged: (v) => session.tweak((o) => o.autoCut = v),
              ),
              Tile(
                leading: const IconBadge(Icons.print_outlined, tone: Tone.neutral, size: 38),
                title: 'Feed after print', subtitle: 'Blank lines to tear cleanly',
                trailing: QtyStepper(value: o.feedLines, min: 0, max: 10, onChanged: (v) => session.tweak((o) => o.feedLines = v)),
              ),
            ]),
            if (session.savedCm >= 0.8) ...[
              const SizedBox(height: 14),
              Banner2('Trimming saves about ${session.savedCm.toStringAsFixed(0)} cm of paper on this print.', icon: Icons.content_cut),
            ],
          ]);
        },
      ),
    );
  }
}
