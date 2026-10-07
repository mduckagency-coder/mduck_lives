import "dart:async";
import "dart:io";
import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:flutter/painting.dart";
import "package:path_provider/path_provider.dart";
import "package:video_player/video_player.dart";

/// Guarda no aparelho os videos, audios e imagens que vem do site, pra cada
/// arquivo ser baixado UMA vez so (o Supabase cobra cada download).
/// A URL de cada upload do admin muda quando o arquivo muda, entao a propria
/// URL serve de chave.
///
/// Regras pra economizar trafego:
///   * video/audio em loop NUNCA toca direto da internet (o player pode
///     baixar de novo a cada volta): baixa o arquivo e toca do aparelho;
///   * imagens usam [MediaCacheImage] (cache em disco, nao so em memoria);
///   * os arquivos ficam numa pasta que o sistema nao limpa sozinho;
///     o que nao for usado ha 60 dias e apagado.
class MediaCache {
  MediaCache._();

  static final Map<String, Future<File?>> _downloads = {};
  static Future<Directory>? _dir;
  static const _maxAge = Duration(days: 60);

  static Future<Directory> _cacheDir() {
    return _dir ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory("${base.path}/media_cache");
      if (!await dir.exists()) await dir.create(recursive: true);
      unawaited(_prune(dir));
      return dir;
    }();
  }

  /// Apaga o que nao e usado ha muito tempo (e restos de downloads parciais).
  static Future<void> _prune(Directory dir) async {
    try {
      final limit = DateTime.now().subtract(_maxAge);
      await for (final f in dir.list()) {
        if (f is! File) continue;
        final stat = await f.stat();
        if (f.path.endsWith(".part") || stat.modified.isBefore(limit)) await f.delete();
      }
    } catch (_) {}
  }

  /// Hash FNV-1a: estavel entre execucoes (String.hashCode nao garante isso).
  static String _fileName(String url) {
    var hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final path = Uri.tryParse(url)?.path ?? "";
    final dot = path.lastIndexOf(".");
    final ext = dot >= 0 && path.length - dot <= 5 ? path.substring(dot) : "";
    return "${hash.toRadixString(16)}$ext";
  }

  /// Arquivo ja baixado, ou null se ainda nao estiver no aparelho.
  static Future<File?> cachedFile(String url) async {
    final file = File("${(await _cacheDir()).path}/${_fileName(url)}");
    if (!await file.exists()) {
      // versoes antigas guardavam na pasta temporaria: aproveita sem baixar de novo
      try {
        final old = File("${(await getTemporaryDirectory()).path}/media_cache/${_fileName(url)}");
        if (!await old.exists()) return null;
        await old.copy(file.path);
        unawaited(old.delete().catchError((_) => old));
      } catch (_) {
        return null;
      }
    }
    // marca como usado (o _prune apaga so o que ficou parado)
    unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
    return file;
  }

  /// Baixa (uma vez so, mesmo se chamado varias vezes) e devolve o arquivo.
  static Future<File?> download(String url) {
    return _downloads.putIfAbsent(url, () async {
      try {
        final cached = await cachedFile(url);
        if (cached != null) return cached;
        final target = File("${(await _cacheDir()).path}/${_fileName(url)}");
        final partial = File("${target.path}.part");
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(Uri.parse(url))).close();
          if (response.statusCode != 200) {
            _downloads.remove(url);
            return null;
          }
          await response.pipe(partial.openWrite());
          return await partial.rename(target.path);
        } finally {
          client.close();
        }
      } catch (error) {
        debugPrint("[MediaCache] falha ao baixar $url: $error");
        _downloads.remove(url);
        return null;
      }
    });
  }

  /// Player de um video/audio do site, sempre tocando do arquivo no aparelho.
  /// Se ainda nao estiver baixado, baixa primeiro (uma vez so). Devolve null
  /// se nao der para baixar dentro de [wait] (a tela segue sem o video e o
  /// download continua para a proxima vez).
  static Future<VideoPlayerController?> controller(String url, {VideoPlayerOptions? options, Duration wait = const Duration(seconds: 25)}) async {
    var file = await cachedFile(url);
    file ??= await download(url).timeout(wait, onTimeout: () => null);
    if (file == null) return null;
    return VideoPlayerController.file(file, videoPlayerOptions: options);
  }
}

/// Imagem da internet com cache em disco (o Image.network so guarda na
/// memoria e baixa tudo de novo a cada vez que o app abre).
@immutable
class MediaCacheImage extends ImageProvider<MediaCacheImage> {
  final String url;
  final double scale;
  const MediaCacheImage(this.url, {this.scale = 1.0});

  @override
  Future<MediaCacheImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(MediaCacheImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: scale,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final file = await MediaCache.download(url);
    final Uint8List bytes;
    if (file != null) {
      bytes = await file.readAsBytes();
    } else {
      // sem cache (ex.: erro ao salvar): baixa direto, como antes
      final client = HttpClient();
      try {
        final res = await (await client.getUrl(Uri.parse(url))).close();
        if (res.statusCode != 200) throw Exception("HTTP ${res.statusCode}");
        bytes = await consolidateHttpClientResponseBytes(res);
      } finally {
        client.close();
      }
    }
    if (bytes.isEmpty) throw Exception("imagem vazia: $url");
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is MediaCacheImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);
}
