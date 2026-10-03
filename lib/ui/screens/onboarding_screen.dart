import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.fromSettings = false});
  final bool fromSettings;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  static const _copy = [
    ('Print anything. No watermark.', 'Nothing extra is ever added to your paper, and the app is free.'),
    ('Share, tap, done.', 'Share a PDF from WhatsApp, Gmail or Files. Parchi opens a preview and prints in one tap.'),
    ('Made for 58mm paper.', 'Parchi trims blank space and joins pages into one roll, so your paper lasts longer.'),
  ];

  void _finish() {
    if (widget.fromSettings) {
      Navigator.of(context).pop();
    } else {
      context.read<AppSettings>().onboarded = true;
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF12161C);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pc,
              onPageChanged: (v) => setState(() => _i = v),
              children: [_paperArt(), _shareArt(), _trimArt()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              height: 150,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_copy[_i].$1, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -0.6)),
                const SizedBox(height: 10),
                Text(_copy[_i].$2, style: const TextStyle(color: Color(0xFFB6BFCC), fontSize: 16, height: 1.4)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Row(children: [
              Row(children: [
                for (var k = 0; k < 3; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    width: k == _i ? 22 : 8, height: 8,
                    decoration: BoxDecoration(color: k == _i ? Colors.white : const Color(0xFF46505F), borderRadius: BorderRadius.circular(4)),
                  ),
              ]),
              const Spacer(),
              TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: Color(0xFFB6BFCC), fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: bg, minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 26)),
                onPressed: () {
                  if (_i < 2) {
                    _pc.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                  } else {
                    _finish();
                  }
                },
                child: Text(_i == 2 ? 'Get started' : 'Next', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _paper(String text) => Transform.rotate(
        angle: -0.05,
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white),
          child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFF1B1B1B), height: 1.3, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _paperArt() => Center(
        child: _paper('  Invoice_0412.pdf\n--------------------\n  Wheat dalia   33,600\n  Master feed   62,000\n  Soya bean     45,500\n--------------------\n  TOTAL        141,100\n\n  thank you'),
      );

  Widget _trimArt() => Center(
        child: _paper(' A4 page  ->  58 mm roll\n --------------------\n  blank space: removed\n  pages: joined\n  paper: saved\n --------------------'),
      );

  Widget _shareArt() {
    Widget box(IconData i, {bool hl = false}) => Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: hl ? const Color(0xFF2447F5) : const Color(0xFF243044), borderRadius: BorderRadius.circular(18)),
          child: Icon(i, color: Colors.white, size: 28),
        );
    const arrow = Icon(Icons.chevron_right, color: Color(0xFF6B778B));
    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        box(Icons.insert_drive_file_outlined), arrow, box(Icons.share_outlined), arrow, box(Icons.print, hl: true),
      ]),
    );
  }
}
