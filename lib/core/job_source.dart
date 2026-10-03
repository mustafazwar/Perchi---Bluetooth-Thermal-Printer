import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' show TextAlign;
import 'package:pdfx/pdfx.dart';

import 'fmt.dart';
import 'models.dart';
import 'raster.dart';

/// Anything that can be turned into grayscale pages at a given dot width.
abstract class JobSource {
  JobKind get kind;
  String get title;
  Map<String, dynamic> toJson();
  Future<List<Gray>> pages(int dots, int cols);

  static JobSource fromJson(Map<String, dynamic> j) {
    switch (j['t']) {
      case 'pdf':
        return PdfSource(j['path'], j['name'] ?? 'document.pdf');
      case 'image':
        return ImageSource(j['path'], j['name'] ?? 'image');
      case 'text':
        return TextSource(j['text'] ?? '', large: j['large'] ?? false);
      case 'receipt':
        return ReceiptSource(ReceiptData.fromJson(Map<String, dynamic>.from(j['data'] as Map)));
      case 'code':
        return CodeSource(
          data: j['data'] ?? '',
          caption: j['caption'] ?? '',
          barcode: j['barcode'] ?? false,
          ean: j['ean'] ?? false,
          sizeMm: j['mm'] ?? 30,
        );
      default:
        return TestSource(j['kind'] ?? 'text');
    }
  }
}

class PdfSource extends JobSource {
  PdfSource(this.path, this.name);
  final String path;
  final String name;
  @override
  JobKind get kind => JobKind.pdf;
  @override
  String get title => name;
  @override
  Map<String, dynamic> toJson() => {'t': 'pdf', 'path': path, 'name': name};

  @override
  Future<List<Gray>> pages(int dots, int cols) async {
    final doc = await PdfDocument.openFile(path);
    try {
      final n = math.min(doc.pagesCount, 40);
      final out = <Gray>[];
      for (var i = 1; i <= n; i++) {
        final page = await doc.getPage(i);
        try {
          // Render at 2x the dot width, then scale down: much sharper small text.
          final scale = (dots * 2) / page.width;
          final img = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (img != null) out.add(await decodeGray(img.bytes, dots));
        } finally {
          await page.close();
        }
      }
      return out;
    } finally {
      await doc.close();
    }
  }
}

class ImageSource extends JobSource {
  ImageSource(this.path, this.name);
  final String path;
  final String name;
  @override
  JobKind get kind => JobKind.image;
  @override
  String get title => name;
  @override
  Map<String, dynamic> toJson() => {'t': 'image', 'path': path, 'name': name};

  @override
  Future<List<Gray>> pages(int dots, int cols) async {
    final bytes = await File(path).readAsBytes();
    return [await decodeGray(bytes, dots)];
  }
}

class TextSource extends JobSource {
  TextSource(this.text, {this.large = false});
  final String text;
  final bool large;
  @override
  JobKind get kind => JobKind.text;
  @override
  String get title {
    final first = text.trim().split('\n').first;
    if (first.isEmpty) return 'Text note';
    return first.length > 30 ? '${first.substring(0, 30)}…' : first;
  }

  @override
  Map<String, dynamic> toJson() => {'t': 'text', 'text': text, 'large': large};

  @override
  Future<List<Gray>> pages(int dots, int cols) async {
    final lines = text.split('\n').map((l) => TLine(l)).toList();
    return [await renderText(lines, dots, fontPx: large ? 36 : 25)];
  }
}

List<TLine> receiptLines(ReceiptData d, int cols) {
  String sep() => '-' * cols;
  String lr(String l, String r) {
    final room = cols - r.length - 1;
    final ll = l.length > room ? l.substring(0, math.max(0, room)) : l;
    return ll + ' ' * math.max(1, cols - ll.length - r.length) + r;
  }

  TLine ctr(String s, {bool bold = false}) =>
      TLine(s, bold: bold, align: TextAlign.center, mono: true);
  TLine mono(String s, {bool bold = false}) => TLine(s, bold: bold, mono: true);

  final out = <TLine>[
    if (d.shop.trim().isNotEmpty) ctr(d.shop.trim().toUpperCase(), bold: true),
    if (d.tagline.trim().isNotEmpty) ctr(d.tagline.trim()),
    mono(sep()),
    mono(lr('Bill #${d.billNo}', d.date)),
    if (d.customer.trim().isNotEmpty) mono('Customer: ${d.customer.trim()}'),
    mono(sep()),
  ];
  for (final it in d.items) {
    final name = it.name.trim();
    if (name.isEmpty && it.amount == 0) continue;
    for (var i = 0; i < name.length; i += cols) {
      out.add(mono(name.substring(i, math.min(name.length, i + cols))));
    }
    out.add(mono(lr('  ${it.qty} x ${fmtNum(it.price)}', fmtNum(it.amount))));
  }
  out.addAll([
    mono(sep()),
    mono(lr('TOTAL', fmtNum(d.total)), bold: true),
    mono(lr('Paid', fmtNum(d.paid))),
    mono(lr('BALANCE', fmtNum(d.total - d.paid)), bold: true),
    mono(sep()),
    if (d.footer.trim().isNotEmpty) ctr(d.footer.trim()),
  ]);
  return out;
}

class ReceiptSource extends JobSource {
  ReceiptSource(this.data);
  final ReceiptData data;
  @override
  JobKind get kind => JobKind.receipt;
  @override
  String get title => data.customer.trim().isEmpty ? 'Bill #${data.billNo}' : 'Bill #${data.billNo} · ${data.customer.trim()}';
  @override
  Map<String, dynamic> toJson() => {'t': 'receipt', 'data': data.toJson()};

  @override
  Future<List<Gray>> pages(int dots, int cols) async =>
      [await renderText(receiptLines(data, cols), dots, monoPx: monoFontPx(dots, cols))];
}

class CodeSource extends JobSource {
  CodeSource({required this.data, this.caption = '', this.barcode = false, this.ean = false, this.sizeMm = 30});
  final String data;
  final String caption;
  final bool barcode;
  final bool ean;
  final int sizeMm;
  @override
  JobKind get kind => barcode ? JobKind.barcode : JobKind.qr;
  @override
  String get title {
    if (data.isEmpty) return barcode ? 'Barcode' : 'QR code';
    return data.length > 28 ? '${data.substring(0, 28)}…' : data;
  }

  @override
  Map<String, dynamic> toJson() =>
      {'t': 'code', 'data': data, 'caption': caption, 'barcode': barcode, 'ean': ean, 'mm': sizeMm};

  @override
  Future<List<Gray>> pages(int dots, int cols) async => [
        await renderCode(width: dots, data: data, caption: caption, barcode: barcode, ean: ean, sizeMm: sizeMm)
      ];
}

/// Built-in test prints for the printer detail screen.
class TestSource extends JobSource {
  TestSource(this.type);
  final String type; // 'text' | 'pattern' | 'qr'
  @override
  JobKind get kind => JobKind.test;
  @override
  String get title => type == 'pattern' ? 'Graphics test' : type == 'qr' ? 'QR test' : 'Text test';
  @override
  Map<String, dynamic> toJson() => {'t': 'test', 'kind': type};

  @override
  Future<List<Gray>> pages(int dots, int cols) async {
    if (type == 'qr') {
      return [await renderCode(width: dots, data: 'https://parchi.app', caption: 'Parchi test', barcode: false, ean: false, sizeMm: 30)];
    }
    if (type == 'pattern') {
      const h = 280;
      final g = blankGray(dots, h);
      final px = g.px;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < dots; x++) {
          var v = 255;
          if (x < 3 || x >= dots - 3 || y < 3 || y >= h - 3) v = 0;
          if (y >= 16 && y < 76) v = (x * 255 ~/ dots); // gradient
          if (y >= 90 && y < 130 && x % 4 < 2) v = 0; // vertical lines
          if (y >= 144 && y < 204 && ((x ~/ 8) + (y ~/ 8)) % 2 == 0) v = 0; // checker
          if (y >= 218 && y < 262 && (x - dots ~/ 2) * (x - dots ~/ 2) + (y - 240) * (y - 240) < 400) v = 0;
          px[y * dots + x] = v;
        }
      }
      return [g];
    }
    final lines = <TLine>[
      const TLine('PARCHI TEST', bold: true, align: TextAlign.center, size: 1.4),
      const TLine('If you can read this, printing works.', align: TextAlign.center),
      TLine('-' * 24),
      const TLine('Normal text'),
      const TLine('Bold text', bold: true),
      const TLine('اردو متن کی جانچ', align: TextAlign.center),
      TLine('-' * 24),
    ];
    return [await renderText(lines, dots, fontPx: 25)];
  }
}
