import 'package:flutter/material.dart';

import '../../core/job_source.dart';
import '../flow.dart';
import '../widgets.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});
  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  final _c = TextEditingController();
  bool _large = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text note')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(children: [
          Expanded(
            child: TextField(
              controller: _c,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: 'Type or paste anything. English and Urdu both print correctly.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Seg<bool>(value: _large, items: const {false: 'Normal text', true: 'Large text'}, onChanged: (v) => setState(() => _large = v)),
          const SizedBox(height: 12),
          PButton('Preview and print', icon: Icons.print, onTap: () {
            if (_c.text.trim().isEmpty) {
              toast('Type something first');
              return;
            }
            openPrintSheet(TextSource(_c.text, large: _large));
          }),
        ]),
      ),
    );
  }
}
