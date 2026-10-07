import "dart:io";
import "package:image/image.dart" as img;

/// Recorta as bordas transparentes do logo (assets/videos/LogoMduck.png)
/// -> assets/videos/LogoMduck_crop.png, usado na barra superior e em Sobre.
void main() {
  final src = img.decodePng(File("assets/videos/LogoMduck.png").readAsBytesSync())!;
  var minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (final p in src) {
    if (p.a > 20) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }
  final out = img.copyCrop(src, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  File("assets/videos/LogoMduck_crop.png").writeAsBytesSync(img.encodePng(out));
  print("${src.width}x${src.height} -> bbox $minX,$minY ${out.width}x${out.height}");
}
