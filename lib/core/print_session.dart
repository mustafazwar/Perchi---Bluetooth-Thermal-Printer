import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'job_source.dart';
import 'models.dart';
import 'raster.dart';

/// Holds one print job: its source, the options, and the live preview.
class PrintSession extends ChangeNotifier {
  PrintSession(this._source, this.opts);

  JobSource _source;
  JobSource get source => _source;
  final PrintOptions opts;

  final Map<int, List<Gray>> _cache = {};
  int _gen = 0;

  Bits? bits;
  ui.Image? preview;
  int rawRows = 0;
  int pageCount = 0;
  bool loading = false;
  String? error;

  void setSource(JobSource s) {
    _source = s;
    _cache.clear();
    refresh();
  }

  /// Change options and rebuild the preview.
  void update(void Function(PrintOptions o) f) {
    f(opts);
    refresh();
  }

  /// Change options that don't affect the picture (copies, feed, cut).
  void tweak(void Function(PrintOptions o) f) {
    f(opts);
    notifyListeners();
  }

  Future<void> refresh() async {
    final gen = ++_gen;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final dots = opts.dots;
      final pages = _cache[dots] ??= await _source.pages(dots, opts.cols);
      final r = process(pages, opts);
      final img = await bitsToImage(r.bits);
      if (gen != _gen) return;
      bits = r.bits;
      preview = img;
      rawRows = r.rawRows;
      pageCount = r.pageCount;
    } catch (e) {
      if (gen == _gen) error = 'Could not prepare this file ($e)';
    }
    if (gen == _gen) {
      loading = false;
      notifyListeners();
    }
  }

  /// Rows (dots) of blank paper saved by trimming, at 8 dots per mm.
  int get savedRows => math.max(0, rawRows - (bits?.h ?? rawRows));
  double get savedCm => savedRows / 8 / 10;
}
