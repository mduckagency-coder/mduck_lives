import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Tipo de registro (mesmas chaves e cores do painel web).
class InventoryType {
  final String key;
  final String emoji;
  final String label;
  final Color color;
  const InventoryType(this.key, this.emoji, this.label, this.color);
}

const inventoryTypes = [
  InventoryType("presente", "🎁", "Presente", Color(0xFFD65CFF)),
  InventoryType("conquista", "🏆", "Conquista", Color(0xFFB45CFF)),
  InventoryType("treinamento", "🎓", "Treinamento", Color(0xFF5B8CFF)),
  InventoryType("recompensa", "🏅", "Premiação", Color(0xFF9B5CFF)),
  InventoryType("campanha", "🎯", "Campanha", Color(0xFFFF6FB5)),
  InventoryType("evento", "🎪", "Evento", Color(0xFF7C5CFF)),
  InventoryType("suporte", "🤝", "Suporte", Color(0xFF3FB6CF)),
  InventoryType("pix", "💰", "Pix", Color(0xFF2EC4B6)),
  InventoryType("reconhecimento", "🎖", "Reconhecimento", Color(0xFFC084FC)),
  InventoryType("evolucao", "📈", "Evolução", Color(0xFF4FA3FF)),
  InventoryType("objetivo", "🚩", "Objetivo", Color(0xFF8A6CFF)),
  InventoryType("outros", "📦", "Outros", Color(0xFF8E9AB8)),
];

InventoryType inventoryTypeOf(String key) =>
    inventoryTypes.firstWhere((t) => t.key == key, orElse: () => inventoryTypes.last);

/// 1234.5 -> "R$ 1.234,50"
String formatBrl(num value) {
  final cents = (value * 100).round();
  final reais = (cents ~/ 100).abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write(".");
    buf.write(reais[i]);
  }
  return "R\$ $buf,${(cents.abs() % 100).toString().padLeft(2, "0")}";
}

class InventoryEntry {
  final String id;
  final String category;
  final String title;
  final String? description;
  final DateTime occurredAt;
  final String? imageUrl;

  /// So vem preenchido quando a agencia marcou o valor como visivel.
  final double? amount;
  final String status;

  /// Nome de quem registrou na equipe (se houver).
  final String? responsible;

  const InventoryEntry({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.occurredAt,
    this.imageUrl,
    this.amount,
    this.status = "concluido",
    this.responsible,
  });

  InventoryType get type => inventoryTypeOf(category);

  factory InventoryEntry.fromMap(Map<String, dynamic> m) => InventoryEntry(
        id: m["id"] as String,
        category: m["category"] as String? ?? "outros",
        title: m["title"] as String? ?? "",
        description: (m["description"] as String?)?.trim().isEmpty ?? true ? null : (m["description"] as String).trim(),
        occurredAt: DateTime.parse(m["occurred_at"] as String),
        imageUrl: (m["image_url"] as String?)?.isEmpty ?? true ? null : m["image_url"] as String,
        amount: (m["amount"] as num?)?.toDouble(),
        status: m["status"] as String? ?? "concluido",
        responsible: (m["responsible"] as String?)?.trim().isEmpty ?? true ? null : (m["responsible"] as String).trim(),
      );
}

/// Tudo que o streamer recebeu/conquistou com a MDUCK Agency (painel web >
/// Inventario). A funcao app_my_inventory (migration 0090) so devolve os
/// registros marcados como visiveis, sem observacao interna e com o valor
/// apenas quando a agencia permitiu mostrar.
class InventoryRepository {
  final _client = Supabase.instance.client;

  Future<List<InventoryEntry>> fetchEntries() async {
    final rows = await _client.rpc("app_my_inventory");
    return [for (final r in (rows as List)) InventoryEntry.fromMap(r as Map<String, dynamic>)];
  }

  /// Diamantes do mes anterior fechado (monthly_stats), pra comparacao.
  /// null se nao houver esse dado.
  Future<({int diamonds, int month})?> fetchPreviousMonthDiamonds() async {
    try {
      final authUserId = _client.auth.currentUser?.id;
      if (authUserId == null) return null;
      final profile = await _client.from("profiles").select("id").eq("auth_user_id", authUserId).single();
      final now = DateTime.now();
      final prev = DateTime(now.year, now.month - 1);
      final key = "${prev.year}-${prev.month.toString().padLeft(2, "0")}";
      final row = await _client
          .from("monthly_stats")
          .select("diamonds")
          .eq("streamer_id", profile["id"])
          .eq("period_key", key)
          .maybeSingle();
      final d = (row?["diamonds"] as num?)?.toInt();
      return d == null ? null : (diamonds: d, month: prev.month);
    } catch (_) {
      return null;
    }
  }
}
