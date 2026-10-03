import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/history.dart';
import '../../core/print_session.dart';
import '../../core/printer_service.dart';
import '../../core/raster.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Phase { preparing, connecting, sending, done, failed }

class PrintingScreen extends StatefulWidget {
  const PrintingScreen({super.key, required this.session});
  final PrintSession session;
  @override
  State<PrintingScreen> createState() => _PrintingScreenState();
}

class _PrintingScreenState extends State<PrintingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  _Phase _phase = _Phase.preparing;
  double _progress = 0;
  String? _error;
  bool _cancel = false;

  @override
  void initState() {
    super.initState();
    _anim.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _cancel = true;
    _anim.dispose();
    super.dispose();
  }

  HistoryEntry _entry(bool ok, String? err) {
    final s = widget.session;
    return HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: s.source.title,
      kind: s.source.kind,
      at: DateTime.now().millisecondsSinceEpoch,
      copies: s.opts.copies,
      ok: ok,
      error: err,
      source: s.source.toJson(),
      savedRows: s.savedRows,
    );
  }

  Future<void> _run() async {
    final s = widget.session;
    final printer = context.read<PrinterService>();
    final hist = context.read<HistoryStore>();
    setState(() {
      _phase = _Phase.preparing;
      _progress = 0;
      _error = null;
      _cancel = false;
    });
    if (!_anim.isAnimating) _anim.repeat();
    try {
      if (s.bits == null || s.loading) await s.refresh();
      if (s.bits == null) throw PrintFailure(s.error ?? 'Nothing to print');
      if (_cancel) return;
      setState(() => _phase = _Phase.connecting);
      if (!await printer.ensureConnected()) {
        final name = printer.settings.lastName;
        throw PrintFailure(printer.settings.lastMac.isEmpty
            ? 'No printer selected. Open the Printers tab and choose yours.'
            : "Can't reach $name. Check it is switched on, has paper and is nearby.");
      }
      if (_cancel) return;
      setState(() => _phase = _Phase.sending);
      final data = escposJob(s.bits!, s.opts);
      await printer.send(data, (v) {
        if (mounted) setState(() => _progress = v);
      }, cancelled: () => _cancel);
      await hist.add(_entry(true, null));
      if (!mounted) return;
      _anim.stop();
      _anim.value = 1;
      setState(() => _phase = _Phase.done);
    } on PrintCancelled {
      // user left the screen
    } catch (e) {
      final msg = e is PrintFailure ? e.message : '$e';
      await hist.add(_entry(false, msg));
      if (!mounted) return;
      _anim.stop();
      setState(() {
        _phase = _Phase.failed;
        _error = msg;
      });
    }
  }

  String get _title {
    switch (_phase) {
      case _Phase.preparing: return 'Preparing…';
      case _Phase.connecting: return 'Connecting…';
      case _Phase.sending: return 'Printing…';
      case _Phase.done: return 'Printed';
      case _Phase.failed: return 'Could not print';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = widget.session;
    final busy = _phase == _Phase.preparing || _phase == _Phase.connecting || _phase == _Phase.sending;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () {
          _cancel = true;
          Navigator.of(context).pop();
        }),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(children: [
            Center(
              child: SizedBox(
                width: 280,
                child: Column(children: [
                  Container(
                    height: 58,
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: p.ink, borderRadius: const BorderRadius.vertical(top: Radius.circular(22), bottom: Radius.circular(8))),
                    child: Icon(Icons.print, color: p.bg, size: 20),
                  ),
                  Container(height: 8, margin: const EdgeInsets.symmetric(horizontal: 30), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4))),
                  ClipRect(
                    child: SizedBox(
                      height: 300, width: 280,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) {
                            final t = Curves.easeOut.transform(_anim.value);
                            return Align(
                              alignment: Alignment.topCenter,
                              child: Transform.translate(offset: Offset(0, -300 * (1 - t)), child: PaperPreview(image: s.preview, width: 240)),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            if (busy) ...[
              Row(children: [
                Text(_phase == _Phase.sending ? 'Sending to printer' : (_phase == _Phase.connecting ? 'Connecting to printer' : 'Preparing your file'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${(_progress * 100).round()}%', style: TextStyle(color: p.mute)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: _phase == _Phase.sending ? _progress : null, minHeight: 10)),
              const SizedBox(height: 14),
              PButton('Cancel print', kind: BKind.danger, onTap: () {
                _cancel = true;
                Navigator.of(context).pop();
              }),
            ],
            if (_phase == _Phase.done) ...[
              Banner2(s.savedCm >= 0.8 ? 'Printed. Saved about ${s.savedCm.toStringAsFixed(0)} cm of paper.' : 'Printed. Tear off your paper.'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: PButton('Print again', kind: BKind.ghost, onTap: _run)),
                const SizedBox(width: 12),
                Expanded(child: PButton('Done', onTap: () => Navigator.of(context).popUntil((r) => r.isFirst))),
              ]),
            ],
            if (_phase == _Phase.failed) ...[
              Banner2(_error ?? 'Printing failed', tone: Tone.bad, icon: Icons.warning_amber_rounded),
              const SizedBox(height: 8),
              Text('Your file is saved in History. Nothing is lost.', style: TextStyle(color: p.mute, fontSize: 13)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: PButton('Later', kind: BKind.ghost, onTap: () => Navigator.of(context).popUntil((r) => r.isFirst))),
                const SizedBox(width: 12),
                Expanded(child: PButton('Reconnect', icon: Icons.refresh, onTap: _run)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
