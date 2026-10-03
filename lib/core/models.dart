import 'dart:typed_data';

enum JobKind { pdf, image, receipt, text, qr, barcode, test }

enum ImageStyle { text, photo, halftone }

class PrintOptions {
  PrintOptions({
    this.paperMm = 58,
    this.darkness = 60,
    this.style = ImageStyle.text,
    this.trim = true,
    this.stitch = true,
    this.invert = false,
    this.copies = 1,
    this.feedLines = 3,
    this.autoCut = false,
  });

  int paperMm;
  int darkness;
  ImageStyle style;
  bool trim;
  bool stitch;
  bool invert;
  int copies;
  int feedLines;
  bool autoCut;

  /// Printable dots across the paper (203 dpi heads).
  int get dots => paperMm >= 80 ? 576 : 384;

  /// Characters per line for receipt text.
  int get cols => paperMm >= 80 ? 48 : 32;
}

/// 8-bit grayscale picture. 255 = white.
class Gray {
  const Gray(this.w, this.h, this.px);
  final int w;
  final int h;
  final Uint8List px;
}

/// 1-bit picture, rows packed 8 pixels per byte, 1 = black dot.
class Bits {
  const Bits(this.w, this.h, this.data);
  final int w;
  final int h;
  final Uint8List data;
  int get rowBytes => (w + 7) >> 3;
}

class ReceiptItem {
  ReceiptItem({this.name = '', this.qty = 1, this.price = 0});
  String name;
  int qty;
  int price;
  int get amount => qty * price;

  Map<String, dynamic> toJson() => {'n': name, 'q': qty, 'p': price};
  factory ReceiptItem.fromJson(Map<String, dynamic> j) =>
      ReceiptItem(name: j['n'] ?? '', qty: j['q'] ?? 1, price: j['p'] ?? 0);
}

class ReceiptData {
  ReceiptData({
    this.shop = '',
    this.tagline = '',
    this.billNo = '',
    this.date = '',
    this.customer = '',
    List<ReceiptItem>? items,
    this.paid = 0,
    this.footer = '',
  }) : items = items ?? [];

  String shop;
  String tagline;
  String billNo;
  String date;
  String customer;
  List<ReceiptItem> items;
  int paid;
  String footer;

  int get total => items.fold(0, (a, b) => a + b.amount);

  Map<String, dynamic> toJson() => {
        'shop': shop,
        'tag': tagline,
        'no': billNo,
        'date': date,
        'cust': customer,
        'items': items.map((e) => e.toJson()).toList(),
        'paid': paid,
        'foot': footer,
      };

  factory ReceiptData.fromJson(Map<String, dynamic> j) => ReceiptData(
        shop: j['shop'] ?? '',
        tagline: j['tag'] ?? '',
        billNo: j['no'] ?? '',
        date: j['date'] ?? '',
        customer: j['cust'] ?? '',
        items: ((j['items'] ?? []) as List)
            .map((e) => ReceiptItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        paid: j['paid'] ?? 0,
        footer: j['foot'] ?? '',
      );
}
