import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../flow.dart';
import '../theme.dart';
import '../widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _f = 'all';

  bool _match(HistoryEntry e) {
    switch (_f) {
      case 'pdf': return e.kind == JobKind.pdf;
      case 'image': return e.kind == JobKind.image;
      case 'made': return e.kind == JobKind.receipt || e.kind == JobKind.text || e.kind == JobKind.qr || e.kind == JobKind.barcode;
      case 'failed': return !e.ok;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final store = context.watch<HistoryStore>();
    final all = store.items;
    final now = DateTime.now();
    final month = all.where((e) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.at);
      return e.ok && d.year == now.year && d.month == now.month;
    }).toList();
    var savedRows = 0;
    for (final e in month) {
      savedRows += e.savedRows * e.copies;
    }
    final savedM = savedRows / 8 / 1000;
    final list = all.where(_match).toList();

    final children = <Widget>[];
    String? last;
    for (final e in list) {
      final label = dayLabel(e.at);
      if (label != last) {
        children.add(SectionLabel(label));
        last = label;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => store.remove(e.id),
          background: Container(
            decoration: BoxDecoration(color: p.badTint, borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_outline, color: p.bad),
          ),
          child: PCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              IconBadge(e.ok ? kindIcon(e.kind) : Icons.warning_amber_rounded, tone: e.ok ? Tone.acc : Tone.bad),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(
                    e.ok ? '${e.copies} ${e.copies == 1 ? 'copy' : 'copies'} · ${clockText(e.at)}' : '${e.error ?? 'Failed'}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: e.ok ? p.mute : p.bad),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              PButton(e.ok ? 'Reprint' : 'Retry', small: true, expand: false, kind: e.ok ? BKind.ghost : BKind.primary, onTap: () => reprint(e)),
            ]),
          ),
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History'), actions: [
        if (all.isNotEmpty)
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text('Saved copies of printed files will be removed too.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) store.clear();
            },
          ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
        Row(children: [
          Expanded(child: _Stat('${month.length}', 'prints this month')),
          const SizedBox(width: 10),
          Expanded(child: _Stat('${savedM.toStringAsFixed(1)} m', 'paper saved by trimming')),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in const {'all': 'All', 'pdf': 'PDF', 'image': 'Image', 'made': 'Created', 'failed': 'Failed'}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(f.value), selected: _f == f.key, onSelected: (_) => setState(() => _f = f.key)),
              ),
          ]),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(children: [
              Icon(Icons.history, size: 44, color: p.mute),
              const SizedBox(height: 10),
              Text('Nothing printed yet', style: TextStyle(color: p.mute, fontWeight: FontWeight.w600)),
            ]),
          ),
        ...children,
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => PCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text(label, style: TextStyle(fontSize: 12.5, color: context.pal.mute)),
        ]),
      );
}
