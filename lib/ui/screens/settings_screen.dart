import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/history.dart';
import '../flow.dart';
import '../../core/settings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final st = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        PCard(
          color: p.ink,
          child: Row(children: [
            const IconBadge(Icons.shield_outlined, tone: Tone.ok),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Free. No watermark. No ads.', style: TextStyle(color: p.bg, fontWeight: FontWeight.w800, fontSize: 15.5)),
                Text('Nothing extra is ever printed on your paper.', style: TextStyle(color: p.bg.withAlpha(180), fontSize: 13)),
              ]),
            ),
          ]),
        ),
        const SectionLabel('When I share a file'),
        ListGroup(children: [
          SwitchTile(title: 'Print without asking', subtitle: 'Skip the preview sheet and print straight away', value: st.printWithoutAsking, onChanged: (v) => st.printWithoutAsking = v),
          SwitchTile(title: 'Trim blank space', subtitle: 'Default for every file', value: st.trim, onChanged: (v) => st.trim = v),
          SwitchTile(title: 'Stitch pages into one roll', value: st.stitch, onChanged: (v) => st.stitch = v),
        ]),
        const SectionLabel('Printing'),
        ListGroup(children: [
          Tile(
            title: 'Default printer',
            subtitle: st.lastName.isEmpty ? 'None selected' : st.lastName,
            trailing: Icon(Icons.chevron_right, color: p.mute),
            onTap: () => shellTab.value = 3,
          ),
          Tile(title: 'Paper width', trailing: SizedBox(width: 150, child: Seg<int>(value: st.paperMm, items: const {58: '58', 80: '80'}, onChanged: (v) => st.paperMm = v))),
          Tile(title: 'Feed after print', trailing: QtyStepper(value: st.feedLines, min: 0, max: 10, onChanged: (v) => st.feedLines = v)),
        ]),
        const SectionLabel('Appearance'),
        PCard(
          child: Seg<int>(value: st.themeIndex, items: const {0: 'System', 1: 'Light', 2: 'Dark'}, onChanged: (v) => st.themeIndex = v),
        ),
        const SectionLabel('Data'),
        ListGroup(children: [
          Tile(
            title: 'Keep history for',
            trailing: SizedBox(width: 180, child: Seg<int>(value: st.historyDays, items: const {7: '7d', 30: '30d', 90: '90d'}, onChanged: (v) {
              st.historyDays = v;
              context.read<HistoryStore>().pruneNow();
            })),
          ),
          Tile(
            title: 'Show welcome again',
            trailing: Icon(Icons.chevron_right, color: p.mute),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen(fromSettings: true))),
          ),
        ]),
        const SizedBox(height: 20),
        Center(child: Text('Parchi 1.0', style: TextStyle(color: p.mute, fontSize: 13))),
      ]),
    );
  }
}
