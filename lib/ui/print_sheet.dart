import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/print_session.dart';
import '../core/printer_service.dart';
import '../core/settings.dart';
import 'flow.dart';
import 'screens/printing_screen.dart';
import 'screens/tune_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// The one-tap sheet that opens when you share a file to Parchi.
class PrintSheet extends StatelessWidget {
  const PrintSheet({super.key, required this.session});
  final PrintSession session;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final printer = context.watch<PrinterService>();
    final st = context.watch<AppSettings>();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final o = session.opts;
        final pages = session.pageCount > 1 ? ' · ${session.pageCount} pages' : '';
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(kindIcon(session.source.kind)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Print with Parchi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('${session.source.title}$pages', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.mute, fontSize: 13)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                Positioned.fill(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.only(top: 12), child: PaperPreview(image: session.preview))),
                  ),
                ),
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 60,
                  child: IgnorePointer(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.card.withAlpha(0), p.card]))),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (session.error != null) Banner2(session.error!, tone: Tone.bad, icon: Icons.warning_amber_rounded)
            else if (session.savedCm >= 0.8)
              Banner2('Trimmed ${session.savedCm.toStringAsFixed(0)} cm of blank space. Saves paper.', icon: Icons.content_cut),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Pill(printer.connected ? '${st.lastName.isEmpty ? 'Printer' : st.lastName} connected' : (st.lastMac.isEmpty ? 'No printer selected' : 'Will reconnect to ${st.lastName}'),
                  tone: printer.connected ? Tone.ok : Tone.warn, dot: true),
              Pill('${o.copies} ${o.copies == 1 ? 'copy' : 'copies'}'),
              Pill('${o.paperMm} mm'),
              Pill('Darkness ${o.darkness}%'),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              SizedBox(
                width: 120,
                child: PButton('Adjust', kind: BKind.ghost, onTap: () {
                  Navigator.of(context).pop();
                  navKey.currentState!.push(MaterialPageRoute(builder: (_) => TuneScreen(session: session)));
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PButton('Print now', icon: Icons.print, onTap: session.bits == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        navKey.currentState!.push(MaterialPageRoute(builder: (_) => PrintingScreen(session: session)));
                      }),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
