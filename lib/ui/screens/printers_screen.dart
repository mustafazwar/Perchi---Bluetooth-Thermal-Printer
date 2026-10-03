import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/job_source.dart';
import '../../core/print_session.dart';
import '../../core/printer_service.dart';
import '../../core/settings.dart';
import '../flow.dart';
import '../theme.dart';
import '../widgets.dart';
import 'printing_screen.dart';

class PrintersScreen extends StatefulWidget {
  const PrintersScreen({super.key});
  @override
  State<PrintersScreen> createState() => _PrintersScreenState();
}

class _PrintersScreenState extends State<PrintersScreen> {
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pr = context.watch<PrinterService>();
    final st = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Printers'), actions: [
        IconButton(tooltip: 'Refresh', onPressed: pr.busy ? null : pr.refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        if (pr.busy) const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator()),
        if (pr.error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Banner2(pr.error!, tone: Tone.warn, icon: Icons.bluetooth_disabled)),
        if (pr.paired.isEmpty && !pr.busy && pr.error == null)
          PCard(child: Text('No paired printers found. Pair your printer once in Android Bluetooth settings, then come back and tap refresh.', style: TextStyle(color: p.mute))),
        if (pr.paired.isNotEmpty)
          ListGroup(children: [
            for (final d in pr.paired)
              Tile(
                leading: IconBadge(Icons.print_outlined, tone: d.macAdress == st.lastMac && pr.connected ? Tone.ok : Tone.neutral),
                title: d.name,
                subtitle: d.macAdress,
                trailing: d.macAdress == st.lastMac
                    ? Pill(pr.connected ? 'Connected' : 'Default', tone: pr.connected ? Tone.ok : Tone.acc, dot: pr.connected)
                    : Text('Set up', style: TextStyle(color: p.acc, fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PrinterDetailScreen(mac: d.macAdress, name: d.name))),
              ),
          ]),
        const SectionLabel('Make it automatic'),
        ListGroup(children: [
          SwitchTile(title: 'Auto-connect', subtitle: 'Reconnect to your printer when the app opens', value: st.autoConnect, onChanged: (v) => st.autoConnect = v),
        ]),
        const SizedBox(height: 14),
        PCard(
          color: p.accTint,
          child: Row(children: [
            const IconBadge(Icons.bluetooth),
            const SizedBox(width: 12),
            Expanded(child: Text('Printer not listed? Switch it on, pair it in Android Bluetooth settings (PIN is usually 0000 or 1234), then tap refresh.', style: TextStyle(color: p.ink, fontSize: 13.5))),
          ]),
        ),
      ]),
    );
  }
}

class PrinterDetailScreen extends StatelessWidget {
  const PrinterDetailScreen({super.key, required this.mac, required this.name});
  final String mac, name;

  void _test(BuildContext context, String type) {
    final session = PrintSession(TestSource(type), context.read<AppSettings>().defaults())..refresh();
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => PrintingScreen(session: session)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final pr = context.watch<PrinterService>();
    final st = context.watch<AppSettings>();
    final isThis = st.lastMac == mac;
    final on = isThis && pr.connected;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        PCard(
          child: Row(children: [
            IconBadge(Icons.print, tone: on ? Tone.ok : Tone.neutral),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(on ? 'Connected' : 'Not connected', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(mac, style: TextStyle(color: p.mute, fontSize: 13)),
            ])),
            Pill(on ? 'Ready' : 'Offline', tone: on ? Tone.ok : Tone.bad, dot: true),
          ]),
        ),
        const SizedBox(height: 12),
        if (on)
          PButton('Disconnect', kind: BKind.ghost, onTap: pr.disconnect)
        else
          PButton(pr.busy ? 'Connecting…' : 'Connect and use this printer', icon: Icons.bluetooth_connected, onTap: pr.busy
              ? null
              : () async {
                  final ok = await pr.connect(mac, name);
                  toast(ok ? '$name connected' : 'Could not connect. Check it is on and nearby.');
                }),
        const SectionLabel('Test print'),
        Row(children: [
          Expanded(child: PButton('Text', kind: BKind.ghost, onTap: () => _test(context, 'text'))),
          const SizedBox(width: 8),
          Expanded(child: PButton('Graphics', kind: BKind.ghost, onTap: () => _test(context, 'pattern'))),
          const SizedBox(width: 8),
          Expanded(child: PButton('QR', kind: BKind.ghost, onTap: () => _test(context, 'qr'))),
        ]),
        const SectionLabel('Printing defaults'),
        PCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paper width', style: TextStyle(color: p.mute, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Seg<int>(value: st.paperMm, items: const {58: '58 mm', 80: '80 mm'}, onChanged: (v) => st.paperMm = v),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Darkness', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${st.darkness}%', style: TextStyle(color: p.mute)),
            ]),
            Slider(value: st.darkness.toDouble(), min: 0, max: 100, divisions: 20, onChanged: (v) => st.darkness = v.round()),
          ]),
        ),
        const SizedBox(height: 12),
        ListGroup(children: [
          SwitchTile(title: 'Auto-cut', subtitle: 'Only if your printer has a cutter', value: st.autoCut, onChanged: (v) => st.autoCut = v),
          Tile(
            title: 'Feed after print',
            subtitle: 'Blank lines so you can tear cleanly',
            trailing: QtyStepper(value: st.feedLines, min: 0, max: 10, onChanged: (v) => st.feedLines = v),
          ),
        ]),
        if (isThis) ...[
          const SizedBox(height: 16),
          PButton('Forget this printer', icon: Icons.delete_outline, kind: BKind.danger, onTap: () async {
            await pr.forgetDefault();
            if (context.mounted) Navigator.of(context).pop();
          }),
        ],
      ]),
    );
  }
}
