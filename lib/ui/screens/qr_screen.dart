import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/job_source.dart';
import '../../core/print_session.dart';
import '../../core/settings.dart';
import '../flow.dart';
import '../theme.dart';
import '../widgets.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, this.barcode = false});
  final bool barcode;
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  late bool _barcode = widget.barcode;
  bool _ean = false;
  double _mm = 30;
  final _data = TextEditingController(text: 'https://example.com');
  final _cap = TextEditingController();
  late final PrintSession _session;
  Timer? _debounce;

  CodeSource _src() => CodeSource(data: _data.text.trim(), caption: _cap.text, barcode: _barcode, ean: _ean, sizeMm: _mm.round());

  @override
  void initState() {
    super.initState();
    if (widget.barcode) _data.text = '123456789012';
    _session = PrintSession(_src(), context.read<AppSettings>().defaults())..refresh();
  }

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _session.setSource(_src()));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _data.dispose();
    _cap.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('QR and barcode')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        Seg<bool>(value: _barcode, items: const {false: 'QR code', true: 'Barcode'}, onChanged: (v) {
          _barcode = v;
          _changed();
        }),
        if (_barcode) ...[
          const SizedBox(height: 10),
          Seg<bool>(value: _ean, items: const {false: 'Code 128', true: 'EAN-13'}, onChanged: (v) {
            _ean = v;
            _changed();
          }),
        ],
        const SizedBox(height: 14),
        TextField(controller: _data, onChanged: (_) => _changed(), decoration: InputDecoration(labelText: _barcode ? 'Code' : 'Content (link, phone, text)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 12),
        TextField(controller: _cap, onChanged: (_) => _changed(), decoration: InputDecoration(labelText: 'Caption under code (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
        if (!_barcode) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Text('Size', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${_mm.round()} mm', style: TextStyle(color: p.mute)),
          ]),
          Slider(value: _mm, min: 15, max: 46, onChanged: (v) {
            _mm = v;
            setState(() {});
          }, onChangeEnd: (_) => _changed()),
        ],
        const SizedBox(height: 14),
        Center(
          child: ListenableBuilder(listenable: _session, builder: (_, __) => PaperPreview(image: _session.preview, width: 220)),
        ),
        const SizedBox(height: 22),
        PButton(_barcode ? 'Print barcode' : 'Print QR', icon: Icons.print, onTap: () => openPrintSheet(_src())),
      ]),
    );
  }
}
