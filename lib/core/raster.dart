import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'models.dart';

// ---------------------------------------------------------------------------
// Decoding
// ---------------------------------------------------------------------------

/// Decode any image bytes (PNG/JPG/WebP...) scaled to [width] dots, as grayscale.
Future<Gray> decodeGray(Uint8List bytes, int width) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  final frame = await codec.getNextFrame();
  final g = await imageToGray(frame.image);
  frame.image.dispose();
  codec.dispose();
  return g;
}

Future<Gray> imageToGray(ui.Image im) async {
  final bd = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
  final src = bd!.buffer.asUint8List();
  final n = im.width * im.height;
  final out = Uint8List(n);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    final a = src[j + 3];
    final l = (src[j] * 77 + src[j + 1] * 150 + src[j + 2] * 29) >> 8;
    out[i] = a == 255 ? l : ((l * a + 255 * (255 - a)) ~/ 255);
  }
  return Gray(im.width, im.height, out);
}

Gray blankGray(int w, int h) => Gray(w, h, Uint8List(w * h)..fillRange(0, w * h, 255));

// ---------------------------------------------------------------------------
// Text rendering (receipts, notes, captions). Rendering text as a picture means
// Urdu and any other script prints correctly on every printer.
// ---------------------------------------------------------------------------

class TLine {
  const TLine(this.text,
      {this.bold = false, this.align = TextAlign.start, this.size = 1.0, this.mono = false});
  final String text;
  final bool bold;
  final TextAlign align;
  final double size;
  final bool mono;
}

final _arabic = RegExp(r'[\u0600-\u06FF]');

/// Font size at which [cols] monospace characters exactly fill [width] dots.
double monoFontPx(int width, int cols) {
  final tp = TextPainter(
    text: const TextSpan(text: 'MMMMMMMMMM', style: TextStyle(fontSize: 20, fontFamily: 'monospace')),
    textDirection: TextDirection.ltr,
  )..layout();
  final charW = tp.width / 10;
  return 20 * ((width - 8) / cols) / charW;
}

Future<Gray> renderText(List<TLine> lines, int width, {double fontPx = 24, double monoPx = 20}) async {
  const padX = 4.0;
  final painters = <TextPainter>[];
  var h = 6.0;
  for (final l in lines) {
    final rtl = _arabic.hasMatch(l.text);
    final tp = TextPainter(
      text: TextSpan(
        text: l.text.isEmpty ? ' ' : l.text,
        style: TextStyle(
          color: Colors.black,
          fontSize: (l.mono ? monoPx : fontPx) * l.size,
          fontWeight: l.bold ? FontWeight.w800 : FontWeight.w600,
          fontFamily: l.mono ? 'monospace' : null,
          height: 1.15,
        ),
      ),
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: l.align,
    )..layout(minWidth: width - padX * 2, maxWidth: width - padX * 2);
    painters.add(tp);
    h += tp.height;
  }
  h += 6;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, width.toDouble(), h));
  c.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), h), Paint()..color = Colors.white);
  var y = 6.0;
  for (final tp in painters) {
    tp.paint(c, Offset(padX, y));
    y += tp.height;
  }
  final img = await rec.endRecording().toImage(width, h.ceil());
  final g = await imageToGray(img);
  img.dispose();
  return g;
}

// ---------------------------------------------------------------------------
// QR + barcode
// ---------------------------------------------------------------------------

Future<Gray> renderCode({
  required int width,
  required String data,
  required String caption,
  required bool barcode,
  required bool ean,
  required int sizeMm,
}) async {
  const pad = 14.0;
  final black = Paint()..color = Colors.black;
  double codeH;
  var bars = <Rect>[];
  String? err;
  QrPainter? qr;
  var side = 0.0;

  if (barcode) {
    codeH = 100;
    try {
      final bc = ean ? Barcode.ean13() : Barcode.code128();
      final probe = bc
          .make(data, width: 1000, height: 10, drawText: false)
          .whereType<BarcodeBar>()
          .where((b) => b.black)
          .toList();
      final minW = probe.map((b) => b.width).reduce(math.min);
      final modules = (1000 / minW).round();
      final avail = width - 2 * pad;
      // Whole dots per module keeps the bars crisp and scannable.
      final m = math.max(1, (avail / modules).floor());
      final w = (modules * m).toDouble();
      final off = (width - w) / 2;
      bars = bc
          .make(data, width: w, height: codeH, drawText: false)
          .whereType<BarcodeBar>()
          .where((b) => b.black)
          .map((b) => Rect.fromLTWH(off + b.left, pad + b.top, b.width, b.height))
          .toList();
    } catch (_) {
      err = ean ? 'EAN-13 needs 12 or 13 digits' : 'Cannot encode this text';
    }
  } else {
    side = (sizeMm * 8).clamp(96, width - 28).toDouble();
    codeH = side;
    try {
      qr = QrPainter(
        data: data.isEmpty ? ' ' : data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
      );
    } catch (_) {
      err = 'Text is too long for a QR code';
    }
  }

  final h = codeH + 2 * pad;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, width.toDouble(), h));
  c.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), h), Paint()..color = Colors.white);
  if (err == null) {
    if (qr != null) {
      c.save();
      c.translate((width - side) / 2, pad);
      qr.paint(c, Size(side, side));
      c.restore();
    }
    for (final r in bars) {
      c.drawRect(r, black);
    }
  }
  final img = await rec.endRecording().toImage(width, h.ceil());
  final codeGray = await imageToGray(img);
  img.dispose();

  final lines = <TLine>[
    if (err != null) TLine(err, align: TextAlign.center, bold: true),
    if (barcode && err == null) TLine(data, align: TextAlign.center),
    if (caption.trim().isNotEmpty) TLine(caption.trim(), align: TextAlign.center, bold: true, size: 1.1),
  ];
  if (lines.isEmpty) return codeGray;
  final text = await renderText(lines, width, fontPx: 24);
  return stitchPages([codeGray, text], 0, width);
}

// ---------------------------------------------------------------------------
// Pipeline: trim -> stitch -> invert -> dither
// ---------------------------------------------------------------------------

/// Cuts blank rows from top and bottom. Returns null if the page is empty.
Gray? trimGray(Gray g, {int pad = 6}) {
  bool blank(int y) {
    final o = y * g.w;
    for (var x = 0; x < g.w; x++) {
      if (g.px[o + x] < 215) return false;
    }
    return true;
  }

  var a = 0;
  while (a < g.h && blank(a)) {
    a++;
  }
  if (a == g.h) return null;
  var b = g.h - 1;
  while (b > a && blank(b)) {
    b--;
  }
  final s = math.max(0, a - pad);
  final e = math.min(g.h, b + 1 + pad);
  return Gray(g.w, e - s, Uint8List.sublistView(g.px, s * g.w, e * g.w));
}

Gray stitchPages(List<Gray> pages, int gap, int w) {
  if (pages.length == 1) return pages.first;
  var total = 0;
  for (final p in pages) {
    total += p.h;
  }
  total += gap * (pages.length - 1);
  final out = Uint8List(w * total)..fillRange(0, w * total, 255);
  var y = 0;
  for (final p in pages) {
    out.setRange(y * w, (y + p.h) * w, p.px);
    y += p.h + gap;
  }
  return Gray(w, total, out);
}

class Processed {
  const Processed(this.bits, this.rawRows, this.pageCount);
  final Bits bits;
  final int rawRows;
  final int pageCount;
}

Processed process(List<Gray> pages, PrintOptions o) {
  final w = o.dots;
  var raw = 0;
  final list = <Gray>[];
  for (final p in pages) {
    raw += p.h;
    if (o.trim) {
      final t = trimGray(p);
      if (t != null) list.add(t);
    } else {
      list.add(p);
    }
  }
  if (list.isEmpty) list.add(blankGray(w, 16));
  final merged = stitchPages(list, o.stitch ? 14 : 120, w);
  return Processed(binarize(merged, o), raw, pages.length);
}

const _bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

Bits binarize(Gray g, PrintOptions o) {
  final w = g.w, h = g.h;
  final rb = (w + 7) >> 3;
  final out = Uint8List(rb * h);
  final bias = (o.darkness - 50) * 2.0; // above 50 = darker
  double v(int i) {
    final l = o.invert ? 255 - g.px[i] : g.px[i];
    return l - bias;
  }

  void black(int x, int y) => out[y * rb + (x >> 3)] |= (0x80 >> (x & 7));

  switch (o.style) {
    case ImageStyle.text:
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (v(y * w + x) < 150) black(x, y);
        }
      }
      break;
    case ImageStyle.halftone:
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final t = (_bayer[(y & 3) * 4 + (x & 3)] + 0.5) * 16;
          if (v(y * w + x) < t) black(x, y);
        }
      }
      break;
    case ImageStyle.photo:
      final buf = Float32List(w * h);
      for (var i = 0; i < buf.length; i++) {
        buf[i] = v(i);
      }
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = y * w + x;
          final old = buf[i];
          final nw = old < 128 ? 0.0 : 255.0;
          if (nw == 0) black(x, y);
          final err = old - nw;
          if (x + 1 < w) buf[i + 1] += err * 7 / 16;
          if (y + 1 < h) {
            if (x > 0) buf[i + w - 1] += err * 3 / 16;
            buf[i + w] += err * 5 / 16;
            if (x + 1 < w) buf[i + w + 1] += err * 1 / 16;
          }
        }
      }
      break;
  }
  return Bits(w, h, out);
}

/// For on-screen preview of exactly what will be printed.
Future<ui.Image> bitsToImage(Bits b) {
  final rb = b.rowBytes;
  final rgba = Uint8List(b.w * b.h * 4);
  var j = 0;
  for (var y = 0; y < b.h; y++) {
    for (var x = 0; x < b.w; x++) {
      final isBlack = (b.data[y * rb + (x >> 3)] & (0x80 >> (x & 7))) != 0;
      final c = isBlack ? 0x16 : 0xFF;
      rgba[j++] = c;
      rgba[j++] = c;
      rgba[j++] = c;
      rgba[j++] = 0xFF;
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, b.w, b.h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

// ---------------------------------------------------------------------------
// ESC/POS
// ---------------------------------------------------------------------------

Uint8List escposJob(Bits b, PrintOptions o) {
  final out = BytesBuilder();
  out.add([0x1B, 0x40]); // initialise
  final rb = b.rowBytes;
  for (var c = 0; c < o.copies; c++) {
    for (var y = 0; y < b.h; y += 128) {
      final rows = math.min(128, b.h - y);
      // GS v 0 : print raster bit image, normal density
      out.add([0x1D, 0x76, 0x30, 0x00, rb & 0xFF, rb >> 8, rows & 0xFF, rows >> 8]);
      out.add(Uint8List.sublistView(b.data, y * rb, (y + rows) * rb));
    }
    out.add([0x1B, 0x64, o.feedLines.clamp(0, 255).toInt()]); // feed n lines
    if (o.autoCut) out.add([0x1D, 0x56, 0x42, 0x00]); // partial cut
  }
  return out.toBytes();
}
