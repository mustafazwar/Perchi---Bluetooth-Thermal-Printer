import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/history.dart';
import '../../core/job_source.dart';
import '../../core/models.dart';
import '../../core/print_session.dart';
import '../../core/settings.dart';
import '../flow.dart';
import '../theme.dart';
import '../widgets.dart';

class _Row {
  _Row(ReceiptItem it)
      : name = TextEditingController(text: it.name),
        price = TextEditingController(text: it.price == 0 ? '' : '${it.price}'),
        qty = it.qty;
  final TextEditingController name;
  final TextEditingController price;
  int qty;
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class BuilderScreen extends StatefulWidget {
  const BuilderScreen({super.key, this.initial, this.templateName});
  final ReceiptData? initial;
  final String? templateName;
  @override
  State<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends State<BuilderScreen> {
  late final TextEditingController _shop, _tag, _bill, _cust, _paid, _foot;
  final List<_Row> _rows = [];
  late final PrintSession _session;
  late final String _date;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final d = widget.initial ??
        ReceiptData(
          shop: 'Pream',
          tagline: 'Grain & Feed Supply',
          billNo: '0001',
          footer: 'Thank you! Shukriya',
          items: [
            ReceiptItem(name: 'Wheat dalia 50kg', qty: 4, price: 8400),
            ReceiptItem(name: 'Master feed 40kg', qty: 10, price: 6200),
            ReceiptItem(name: 'Soya bean 50kg', qty: 5, price: 9100),
          ],
          paid: 100000,
        );
    _date = fmtDate(DateTime.now());
    _shop = TextEditingController(text: d.shop);
    _tag = TextEditingController(text: d.tagline);
    _bill = TextEditingController(text: d.billNo);
    _cust = TextEditingController(text: d.customer);
    _paid = TextEditingController(text: d.paid == 0 ? '' : '${d.paid}');
    _foot = TextEditingController(text: d.footer);
    for (final it in d.items) {
      _rows.add(_Row(it));
    }
    _session = PrintSession(ReceiptSource(_data()), context.read<AppSettings>().defaults())..refresh();
  }

  ReceiptData _data() => ReceiptData(
        shop: _shop.text,
        tagline: _tag.text,
        billNo: _bill.text,
        date: _date,
        customer: _cust.text,
        paid: int.tryParse(_paid.text.trim()) ?? 0,
        footer: _foot.text,
        items: _rows.map((r) => ReceiptItem(name: r.name.text, qty: r.qty, price: int.tryParse(r.price.text.trim()) ?? 0)).toList(),
      );

  void _changed() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _session.setSource(ReceiptSource(_data())));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_shop, _tag, _bill, _cust, _paid, _foot]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    _session.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ctl = TextEditingController(text: widget.templateName ?? (_shop.text.trim().isEmpty ? 'My bill' : '${_shop.text.trim()} bill'));
    final store = context.read<TemplateStore>();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save template'),
        content: TextField(controller: ctl, autofocus: true, decoration: const InputDecoration(labelText: 'Template name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await store.save(name, _data());
    toast('Template saved');
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = _data();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt builder'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
        Center(child: Text('Live preview of the real print', style: TextStyle(color: p.mute, fontSize: 12.5))),
        const SizedBox(height: 8),
        Center(
          child: ListenableBuilder(
            listenable: _session,
            builder: (_, __) => PaperPreview(image: _session.preview),
          ),
        ),
        const SizedBox(height: 20),
        PCard(
          child: Column(children: [
            TextField(controller: _shop, onChanged: (_) => _changed(), decoration: _dec('Shop name')),
            const SizedBox(height: 10),
            TextField(controller: _tag, onChanged: (_) => _changed(), decoration: _dec('Tagline or phone')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _bill, onChanged: (_) => _changed(), decoration: _dec('Bill no.'))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: TextField(controller: _cust, onChanged: (_) => _changed(), decoration: _dec('Customer'))),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              PButton('Add', small: true, expand: false, kind: BKind.ghost, icon: Icons.add, onTap: () {
                _rows.add(_Row(ReceiptItem()));
                _changed();
              }),
            ]),
            const SizedBox(height: 8),
            for (var i = 0; i < _rows.length; i++) _itemRow(i, p),
          ]),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(children: [
            _tot('Total', fmtNum(d.total), false),
            Row(children: [
              const Text('Paid', style: TextStyle(fontSize: 15)),
              const Spacer(),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _paid, onChanged: (_) => _changed(),
                  keyboardType: TextInputType.number, textAlign: TextAlign.right,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('Amount'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            _tot('Balance', fmtNum(d.total - d.paid), true),
            const SizedBox(height: 8),
            TextField(controller: _foot, onChanged: (_) => _changed(), decoration: _dec('Footer line')),
          ]),
        ),
        const SizedBox(height: 14),
        PButton('Print bill', icon: Icons.print, onTap: () => openPrintSheet(ReceiptSource(_data()))),
      ]),
    );
  }

  Widget _tot(String l, String v, bool big) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(l, style: TextStyle(fontSize: big ? 18 : 15, fontWeight: big ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text(v, style: TextStyle(fontSize: big ? 18 : 15, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _itemRow(int i, Pal p) {
    final r = _rows[i];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: r.name, onChanged: (_) => _changed(), decoration: _dec('Item'))),
          IconButton(
            icon: Icon(Icons.delete_outline, color: p.bad),
            onPressed: () {
              _rows.removeAt(i).dispose();
              _changed();
            },
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(
            width: 120,
            child: TextField(
              controller: r.price, onChanged: (_) => _changed(), keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _dec('Price'),
            ),
          ),
          const Spacer(),
          QtyStepper(value: r.qty, onChanged: (v) {
            r.qty = v;
            _changed();
          }),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(fmtNum(r.qty * (int.tryParse(r.price.text.trim()) ?? 0)), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
