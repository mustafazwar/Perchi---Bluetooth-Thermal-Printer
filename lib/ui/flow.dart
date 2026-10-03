import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/history.dart';
import '../core/job_source.dart';
import '../core/print_session.dart';
import '../core/settings.dart';
import 'print_sheet.dart';
import 'screens/printing_screen.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// Which bottom tab is showing (0 Print, 1 Create, 2 History, 3 Printers, 4 Settings).
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

BuildContext? get _ctx => navKey.currentState?.overlay?.context;

void toast(String m) {
  final c = _ctx;
  if (c == null) return;
  ScaffoldMessenger.maybeOf(c)?.showSnackBar(SnackBar(content: Text(m)));
}

String _name(String path) => path.split(RegExp(r'[\\/]')).last;

/// Copy a file into app storage so it can be reprinted later.
Future<String> keepFile(String path) async {
  final dir = await getApplicationDocumentsDirectory();
  final d = Directory('${dir.path}/jobs');
  if (!d.existsSync()) d.createSync(recursive: true);
  final dest = '${d.path}/${DateTime.now().millisecondsSinceEpoch}_${_name(path)}';
  await File(path).copy(dest);
  return dest;
}

/// Opens the "Print with Parchi" bottom sheet for any job.
Future<void> openPrintSheet(JobSource src, {bool fromShare = false}) async {
  final ctx = _ctx;
  if (ctx == null) return;
  final settings = ctx.read<AppSettings>();
  final session = PrintSession(src, settings.defaults())..refresh();
  if (fromShare && settings.printWithoutAsking) {
    navKey.currentState!.push(MaterialPageRoute(builder: (_) => PrintingScreen(session: session)));
    return;
  }
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: ctx.pal.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => PrintSheet(session: session),
  );
}

Future<void> pickAndOpen({required bool pdf}) async {
  try {
    final file = await FilePicker.pickFile(
      type: pdf ? FileType.custom : FileType.image,
      allowedExtensions: pdf ? ['pdf'] : null,
    );
    final path = file?.path;
    if (path == null) return;
    final kept = await keepFile(path);
    openPrintSheet(pdf ? PdfSource(kept, _name(path)) : ImageSource(kept, _name(path)));
  } catch (_) {
    toast('Could not open that file');
  }
}

Future<void> pasteText() async {
  final d = await Clipboard.getData('text/plain');
  final t = d?.text?.trim() ?? '';
  if (t.isEmpty) {
    toast('Clipboard is empty');
    return;
  }
  openPrintSheet(TextSource(t));
}

/// Called when another app shares a file or text to Parchi.
Future<void> intakeShared(String path, {required bool isText, required bool isImage}) async {
  if (isText) {
    openPrintSheet(TextSource(path), fromShare: true);
    return;
  }
  final lower = path.toLowerCase();
  try {
    if (lower.endsWith('.pdf')) {
      openPrintSheet(PdfSource(await keepFile(path), _name(path)), fromShare: true);
    } else if (isImage || RegExp(r'\.(jpe?g|png|webp|bmp|gif)$').hasMatch(lower)) {
      openPrintSheet(ImageSource(await keepFile(path), _name(path)), fromShare: true);
    } else {
      toast('Parchi can print PDF files, images and text.');
    }
  } catch (_) {
    toast('Could not open the shared file');
  }
}

void reprint(HistoryEntry e) {
  final ctx = _ctx;
  if (ctx == null) return;
  final path = e.source['path'];
  if (path is String && !File(path).existsSync()) {
    toast('The original file is no longer available');
    return;
  }
  final session = PrintSession(JobSource.fromJson(e.source), ctx.read<AppSettings>().defaults())..refresh();
  navKey.currentState!.push(MaterialPageRoute(builder: (_) => PrintingScreen(session: session)));
}
