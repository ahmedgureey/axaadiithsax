// Builds the launcher icon images from the supplied logo.
//
// The logo arrived with a grey/white "transparency" checkerboard painted into
// it. Starting from the image border, neutral light pixels (the checkerboard)
// are flood-filled to transparent; the gold frame stops the fill, so the
// logo itself (including the white book pages inside) is untouched.
//
//   dart run tool/make_app_icon.dart assets/icon/source_logo.webp
//
// Writes assets/icon/app_icon.png (logo, transparent background, square) and
// assets/icon/app_icon_foreground.png (logo inside the adaptive-icon safe
// zone) for flutter_launcher_icons.
import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

bool _isBackground(img.Pixel p) {
  final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
  final maxC = [r, g, b].reduce((a, c) => a > c ? a : c);
  final minC = [r, g, b].reduce((a, c) => a < c ? a : c);
  return maxC - minC <= 18 && minC >= 150; // light and colourless
}

void main(List<String> args) {
  final src = img.decodeImage(File(args.first).readAsBytesSync())!;
  final im = src.convert(numChannels: 4);
  final w = im.width, h = im.height;
  final seen = List<bool>.filled(w * h, false);
  final queue = Queue<int>();
  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (seen[i]) return;
    seen[i] = true;
    if (_isBackground(im.getPixel(x, y))) queue.add(i);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  var cleared = 0;
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    im.getPixel(x, y).a = 0;
    cleared++;
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }

  // Bounding box of the remaining logo.
  var minX = w, minY = h, maxX = 0, maxY = 0;
  for (final p in im) {
    if (p.a > 0) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }
  final logo = img.copyCrop(im, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  stdout.writeln('cleared $cleared px; logo ${logo.width}x${logo.height}');

  img.Image onCanvas(int size, double fill) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    final scale = (size * fill) / (logo.width > logo.height ? logo.width : logo.height);
    final resized = img.copyResize(
      logo,
      width: (logo.width * scale).round(),
      height: (logo.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(canvas, resized, dstX: (size - resized.width) ~/ 2, dstY: (size - resized.height) ~/ 2);
    return canvas;
  }

  // Legacy/round icon: logo fills most of the square.
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(onCanvas(1024, 0.92)));
  // Adaptive foreground: flutter_launcher_icons adds a 16% inset, which keeps
  // the logo inside the ~66% safe zone.
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(onCanvas(1024, 0.92)));
  stdout.writeln('wrote assets/icon/app_icon.png and assets/icon/app_icon_foreground.png');
}
