import "dart:io";
import "package:mduck_lives/core/media/media_cache.dart";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "data/island_repository.dart";
import "../home/data/streamer_repository.dart";
import "widgets/cropped_media.dart";

class _RarityMeta {
  final String label;
  final Color color;
  const _RarityMeta(this.label, this.color);
}

const _rarityMeta = {
  "comum": _RarityMeta("Comum", Color(0xFF9E9E9E)),
  "classico": _RarityMeta("Clássico", Color(0xFF69F0AE)),
  "raro": _RarityMeta("Raro", Color(0xFF4FC3F7)),
  "epico": _RarityMeta("Épico", Color(0xFFB026FF)),
  "lendario": _RarityMeta("Lendário", Color(0xFFFFD700)),
};
const _defaultRarity = _RarityMeta("Avatar", Color(0xFFB026FF));

String _stripAccents(String s) => s
    .toLowerCase()
    .replaceAll(RegExp("[áàâã]"), "a")
    .replaceAll(RegExp("[éê]"), "e")
    .replaceAll("í", "i")
    .replaceAll(RegExp("[óô]"), "o")
    .replaceAll("ú", "u")
    .replaceAll("ç", "c");

_RarityMeta _rarityFor(String? key) => _rarityMeta[_stripAccents(key ?? "")] ?? _defaultRarity;

/// Se o modo teste tiver um override pra essa raridade (rarity_locks),
/// ele manda: true = bloqueado mesmo com diamantes suficientes, false =
/// liberado mesmo sem bater o min_diamonds. Sem override, vale a regra
/// normal (diamantes do mes >= min_diamonds do avatar).
bool _isUnlocked(IslandAvatarOption option, int myDiamonds, IslandTestConfig? testConfig) {
  final override = testConfig?.rarityLocks[_stripAccents(option.rarity ?? "")];
  if (override != null) return !override;
  return myDiamonds >= option.minDiamonds;
}

const _grayscaleMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

Widget _maybeGrayscale({required bool grayscale, required Widget child}) {
  if (!grayscale) return child;
  return ColorFiltered(colorFilter: const ColorFilter.matrix(_grayscaleMatrix), child: child);
}

class _AvatarPickerData {
  final List<IslandAvatarOption> options;
  final String? currentAvatarId;
  final int myDiamonds;
  final IslandTestConfig? testConfig;
  const _AvatarPickerData({required this.options, this.currentAvatarId, required this.myDiamonds, this.testConfig});
}

/// Bottom sheet com o catalogo de avatares: mostra o que ja esta desbloqueado
/// (diamantes do mes >= min_diamonds do avatar, ou o override do modo teste)
/// e o que ainda falta, com previa ao tocar. So deixa escolher/equipar o que
/// ja esta desbloqueado. Retorna `true` no pop quando uma escolha foi salva.
class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({super.key});

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  final _repository = IslandRepository();
  late Future<_AvatarPickerData> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AvatarPickerData> _load() async {
    final options = await _repository.fetchAvatarOptions();
    final current = await _repository.fetchMyAvatarId();
    final testMode = await _repository.fetchTestMode();
    final testConfig = testMode ? await _repository.fetchTestConfig() : null;
    int diamonds = 0;
    try {
      diamonds = (await StreamerRepository().fetchCurrentStreamerSummary()).diamonds;
    } catch (_) {
      // segue com 0 se a busca falhar; avatares aparecem todos bloqueados
    }
    return _AvatarPickerData(options: options, currentAvatarId: current, myDiamonds: diamonds, testConfig: testConfig);
  }

  Future<void> _choose(IslandAvatarOption option) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.chooseAvatar(option.id);
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _ShareAvatarDialog(option: option),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao escolher pato: $e")));
      setState(() => _saving = false);
    }
  }

  void _openPreview(IslandAvatarOption option, bool unlocked, int myDiamonds) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        final rarity = _rarityFor(option.rarity);
        final missing = (option.minDiamonds - myDiamonds).clamp(0, option.minDiamonds);
        final progress = option.minDiamonds <= 0 ? 1.0 : (myDiamonds / option.minDiamonds).clamp(0.0, 1.0);
        const fallbackIcon = Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 40));

        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: _maybeGrayscale(
                    grayscale: !unlocked,
                    child: Opacity(
                      opacity: unlocked ? 1 : 0.55,
                      child: CroppedMedia(
                        mediaUrl: option.mediaUrl,
                        fallbackImageUrl: option.previewImageUrl,
                        muted: option.muted,
                        volume: option.volume,
                        loopVideo: option.loopVideo,
                        // sem crop_scale/offset aqui de proposito: essa previa
                        // quer mostrar o avatar inteiro, sem o corte pensado
                        // pra preencher um circulo.
                        fit: BoxFit.contain,
                        fallback: fallbackIcon,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: rarity.color.withOpacity(0.18), borderRadius: BorderRadius.circular(12), border: Border.all(color: rarity.color.withOpacity(0.55))),
                  child: Text(rarity.label.toUpperCase(), style: TextStyle(color: rarity.color, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text(option.label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                if (unlocked) ...[
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF69F0AE), size: 16),
                      SizedBox(width: 6),
                      Text("Desbloqueado", style: TextStyle(color: Color(0xFF69F0AE), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop();
                              _choose(option);
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text("Usar esse avatar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(rarity.color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    missing > 0 ? "Faltam $missing diamantes para desbloquear" : "Continue evoluindo pra desbloquear!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text("Precisa de ${option.minDiamonds} diamantes no mês", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Fechar", style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A0B2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: FutureBuilder<_AvatarPickerData>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final unlockedCount = data.options.where((o) => _isUnlocked(o, data.myDiamonds, data.testConfig)).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("Seus patos", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (data.testConfig != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withOpacity(0.6)),
                          ),
                          child: const Text("🧪 MODO TESTE", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$unlockedCount de ${data.options.length} desbloqueados esse mês — toque num avatar pra ver a prévia.",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: data.options.isEmpty
                        ? const Center(
                            child: Text("Nenhum avatar disponível ainda.", style: TextStyle(color: Colors.white54)),
                          )
                        : GridView.builder(
                            controller: scrollController,
                            itemCount: data.options.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.8,
                            ),
                            itemBuilder: (context, i) {
                              final option = data.options[i];
                              final selected = option.id == data.currentAvatarId;
                              final unlocked = _isUnlocked(option, data.myDiamonds, data.testConfig);
                              final rarity = _rarityFor(option.rarity);
                              const fallbackIcon = Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 28));

                              return GestureDetector(
                                onTap: () => _openPreview(option, unlocked, data.myDiamonds),
                                child: Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          height: 64,
                                          child: _maybeGrayscale(
                                            grayscale: !unlocked,
                                            child: Opacity(
                                              opacity: unlocked ? 1 : 0.5,
                                              // gif/video do avatar direto na grade, ja animando —
                                              // sem esperar abrir a previa pra ver como ele e de verdade.
                                              child: CroppedMedia(
                                                mediaUrl: option.mediaUrl,
                                                fallbackImageUrl: option.previewImageUrl,
                                                muted: option.muted,
                                                volume: option.volume,
                                                loopVideo: option.loopVideo,
                                                fit: BoxFit.contain,
                                                fallback: fallbackIcon,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (selected)
                                          Positioned(
                                            left: -2,
                                            top: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
                                              child: const Icon(Icons.check, size: 12, color: Colors.black),
                                            ),
                                          ),
                                        if (!unlocked)
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black87),
                                              child: const Icon(Icons.lock, size: 12, color: Colors.white70),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      option.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: unlocked ? Colors.white70 : Colors.white38, fontSize: 10),
                                    ),
                                    Text(
                                      unlocked ? rarity.label : "${option.minDiamonds} 💎",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: unlocked ? rarity.color : Colors.white30, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Cartao mostrado logo apos escolher um avatar: avatar + foto + nome +
/// diamantes do mes + posicao na agencia, com botao pra compartilhar como
/// imagem (mesmo padrao de captura via RepaintBoundary usado no ranking).
class _ShareAvatarDialog extends StatefulWidget {
  final IslandAvatarOption option;

  const _ShareAvatarDialog({required this.option});

  @override
  State<_ShareAvatarDialog> createState() => _ShareAvatarDialogState();
}

class _ShareAvatarDialogState extends State<_ShareAvatarDialog> {
  final _shareKey = GlobalKey();
  bool _sharing = false;
  StreamerSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await StreamerRepository().fetchCurrentStreamerSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      // segue sem nome/foto/diamantes/posicao se a busca falhar
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/meu_avatar.png");
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)], text: "Escolhi meu novo pato na Ilha Top da MDuck!");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao compartilhar: $e")));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    const fallbackDuck = Center(child: Text("🦆", style: TextStyle(fontSize: 56)));

    return Dialog(
      backgroundColor: const Color(0xFF1A0B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _shareKey,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A1B5E), Color(0xFF1A0F3D)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFB026FF).withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Novo avatar equipado!", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB026FF)]),
                              boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 16, spreadRadius: 1)],
                            ),
                            child: ClipOval(
                              child: CroppedMedia(
                                mediaUrl: widget.option.mediaUrl,
                                fallbackImageUrl: widget.option.previewImageUrl,
                                muted: widget.option.muted,
                                volume: widget.option.volume,
                                loopVideo: widget.option.loopVideo,
                                cropScale: widget.option.cropScale,
                                cropOffsetX: widget.option.cropOffsetX,
                                cropOffsetY: widget.option.cropOffsetY,
                                fallback: fallbackDuck,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -2,
                            left: -2,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black87,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: ClipOval(
                                child: summary?.avatarUrl == null || summary!.avatarUrl!.isEmpty
                                    ? const Icon(Icons.person, size: 16, color: Colors.white70)
                                    : Image(image: MediaCacheImage(summary.avatarUrl!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stack) => const Icon(Icons.person, size: 16, color: Colors.white70),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      summary?.displayName ?? "...",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(12)),
                          child: Text("${summary?.diamonds ?? 0} 💎", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (summary?.rankingPosition != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.55)),
                            ),
                            child: Text("#${summary!.rankingPosition} na agência", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing ? null : _share,
                    icon: _sharing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share, color: Colors.white, size: 18),
                    label: const Text("Compartilhar", style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Concluir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
