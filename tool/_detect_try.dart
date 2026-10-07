import "dart:io";
import "package:image/image.dart" as img;
import "package:mduck_lives/features/inventory/data/art_slots.dart";
void main() {
  for (final f in Directory("C:/Users/gisel/AppData/Local/Temp/claude/C--Users-gisel-mduck-lives/ff1d1cc8-7749-4dc7-8860-bf6cf4954784/scratchpad/arts").listSync().whereType<File>().where((f) => f.path.endsWith(".jpeg"))) {
    final bytes = f.readAsBytesSync();
    final sw = Stopwatch()..start();
    final s = detectArtSlots(bytes);
    print("${f.uri.pathSegments.last}: ${s?.toJson()} (${sw.elapsedMilliseconds}ms)");
    if (s == null) continue;
    final im = img.decodeImage(bytes)!;
    final w = im.width, h = im.height;
    img.drawCircle(im, x: (s.cx * w).round(), y: (s.cy * h).round(), radius: (s.r * w).round(), color: img.ColorRgb8(0, 255, 0));
    if (s.hasPlate) img.drawRect(im, x1: (s.px! * w).round(), y1: (s.py! * h).round(), x2: ((s.px! + s.pw!) * w).round(), y2: ((s.py! + s.ph!) * h).round(), color: img.ColorRgb8(0, 255, 0), thickness: 3);
    File("C:/Users/gisel/AppData/Local/Temp/claude/C--Users-gisel-mduck-lives/ff1d1cc8-7749-4dc7-8860-bf6cf4954784/scratchpad/arts/det_${f.uri.pathSegments.last}.png").writeAsBytesSync(img.encodePng(img.copyResize(im, width: 400)));
  }
}
