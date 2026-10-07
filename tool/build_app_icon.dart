// Gera as artes do icone do app a partir da arte mestre do painel web
// (Icone do Aplicativo -> app_settings 'app_icon_default').
//   dart run tool/build_app_icon.dart && dart run flutter_launcher_icons
import "dart:io";
import "package:image/image.dart" as img;

void main() {
  final src = img.decodeImage(File("assets/icon/app_icon_src.jpeg").readAsBytesSync())!;
  final full = img.copyResize(src, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
  File("assets/icon/app_icon.png").writeAsBytesSync(img.encodePng(full));

  // Cor de fundo do icone adaptativo = media das bordas da arte.
  var r = 0, g = 0, b = 0, n = 0;
  for (var i = 0; i < 1024; i += 8) {
    for (final p in [full.getPixel(i, 2), full.getPixel(i, 1021), full.getPixel(2, i), full.getPixel(1021, i)]) {
      r += p.r.toInt(); g += p.g.toInt(); b += p.b.toInt(); n++;
    }
  }
  final hex = [r ~/ n, g ~/ n, b ~/ n].map((v) => v.toRadixString(16).padLeft(2, "0")).join();
  stdout.writeln("#$hex");

  // Android adaptativo: o celular recorta o icone (circulo, gota, quadrado
  // arredondado) e so ~66% do centro aparece. A arte vai a 60% para o texto
  // da parte de baixo (MDUCK Agency) caber inteiro ate no recorte redondo.
  final fg = img.Image(width: 1024, height: 1024, numChannels: 4);
  const size = 614;
  final inner = img.copyResize(src, width: size, height: size, interpolation: img.Interpolation.cubic).convert(numChannels: 4);
  // Borda esfumada: a arte se mistura com a cor de fundo, sem "quadrado".
  const feather = 36;
  for (final p in inner) {
    final d = [p.x, p.y, size - 1 - p.x, size - 1 - p.y].reduce((a, b) => a < b ? a : b);
    if (d < feather) p.a = 255 * (d / feather) * (d / feather);
  }
  img.compositeImage(fg, inner, dstX: (1024 - size) ~/ 2, dstY: (1024 - size) ~/ 2);
  File("assets/icon/app_icon_foreground.png").writeAsBytesSync(img.encodePng(fg));
}
