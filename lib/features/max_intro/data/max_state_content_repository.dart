import "package:supabase_flutter/supabase_flutter.dart";
import "../domain/max_state.dart";

enum MaxMediaType { image, video }

class MaxStateContent {
  final MaxMediaType mediaType;
  final String mediaUrl;
  const MaxStateContent({required this.mediaType, required this.mediaUrl});
}

const _stateKeys = {
  MaxState.regular: "regular",
  MaxState.constante: "constante",
  MaxState.inativo: "inativo",
  MaxState.caveira: "caveira",
};

const _maxStatesBucket = "max_states";

/// Busca a midia (imagem/video) cadastrada para cada estado do Max na
/// tabela `max_state_media`. Essa tabela ainda nao tem um painel para
/// alimenta-la (isso fica para uma fase futura), mas o app ja consulta por
/// ela para nunca depender de midia fixa no codigo: quando nao houver
/// registro (tabela vazia, ainda nao migrada, ou sem conteudo ativo para o
/// estado), retorna null e quem chamou usa o asset padrao do app.
class MaxStateContentRepository {
  final _client = Supabase.instance.client;

  Future<MaxStateContent?> fetchContentFor(MaxState state, {dynamic agencyId}) async {
    try {
      final stateKey = _stateKeys[state]!;
      final rows = await _client.from("max_state_media").select("*");

      final now = DateTime.now();
      final candidates = (rows as List).where((r) {
        final rowAgency = r["agency_id"];
        if (rowAgency != null && agencyId != null && rowAgency.toString() != agencyId.toString()) return false;
        if (r["is_active"] == false || r["active"] == false) return false;
        if (r["state_key"] != stateKey) return false;

        final validFrom = r["valid_from"] as String?;
        if (validFrom != null) {
          final from = DateTime.tryParse(validFrom);
          if (from != null && now.isBefore(from)) return false;
        }
        final validUntil = r["valid_until"] as String?;
        if (validUntil != null) {
          final until = DateTime.tryParse(validUntil);
          if (until != null && now.isAfter(until)) return false;
        }
        return true;
      }).toList();

      if (candidates.isEmpty) return null;

      candidates.sort((a, b) {
        final aGlobal = a["agency_id"] == null ? 1 : 0;
        final bGlobal = b["agency_id"] == null ? 1 : 0;
        if (aGlobal != bGlobal) return aGlobal.compareTo(bGlobal);
        return ((a["sort_order"] as int?) ?? 0).compareTo((b["sort_order"] as int?) ?? 0);
      });

      final chosen = candidates.first;
      final mediaTypeValue = chosen["media_type"];
      final mediaType = mediaTypeValue.toString().toLowerCase() == "image" ? MaxMediaType.image : MaxMediaType.video;
      final storagePath = chosen["storage_path"] as String?;
      if (storagePath == null || storagePath.isEmpty) return null;

      return MaxStateContent(
        mediaType: mediaType,
        mediaUrl: _client.storage.from(_maxStatesBucket).getPublicUrl(storagePath),
      );
    } catch (_) {
      // Tabela pode ainda nao existir nesse ambiente - fallback silencioso.
      return null;
    }
  }

}
