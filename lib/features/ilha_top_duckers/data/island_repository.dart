import "package:supabase_flutter/supabase_flutter.dart";

/// Normaliza o valor salvo em island_avatars.display_shape pros 3 modos
/// aceitos no app (circle/square/none). So um valor null/vazio (coluna
/// nunca preenchida) mantem o visual antigo (circulo com borda), pra nao
/// quebrar avatares cadastrados antes dessa opcao existir. Qualquer valor
/// preenchido que nao seja claramente "quadrado" ou "circulo" cai em "none"
/// (sem moldura nenhuma) — assim funciona independente da palavra exata
/// usada no admin pra essa terceira opcao (nada, nenhum, transparente etc).
String? _normalizeDisplayShape(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.toLowerCase();
  if (s.contains("quad")) return "square";
  if (s.contains("circ")) return "circle";
  return "none";
}

class IslandBackground {
  final String mediaUrl;
  final String mediaType;
  final String? label;
  final bool muted;
  final double volume;
  final bool loopVideo;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;

  const IslandBackground({
    required this.mediaUrl,
    required this.mediaType,
    this.label,
    required this.muted,
    required this.volume,
    required this.loopVideo,
    required this.cropScale,
    required this.cropOffsetX,
    required this.cropOffsetY,
  });

  factory IslandBackground.fromMap(Map<String, dynamic> m) => IslandBackground(
        mediaUrl: m["media_url"] as String,
        mediaType: m["media_type"] as String? ?? "image",
        label: m["label"] as String?,
        muted: m["muted"] as bool? ?? true,
        volume: (m["volume"] as num?)?.toDouble() ?? 0,
        loopVideo: m["loop_video"] as bool? ?? true,
        cropScale: (m["crop_scale"] as num?)?.toDouble() ?? 1,
        cropOffsetX: (m["crop_offset_x"] as num?)?.toDouble() ?? 0,
        cropOffsetY: (m["crop_offset_y"] as num?)?.toDouble() ?? 0,
      );

  bool get isVideo => mediaType == "video";
}

class IslandSlot {
  final String slotKey;
  final String? label;
  final double posX;
  final double posY;
  final double scale;
  final double minScale;
  final double areaWidth;
  final double areaHeight;
  final int zIndex;
  final bool isEnabled;

  const IslandSlot({
    required this.slotKey,
    this.label,
    required this.posX,
    required this.posY,
    required this.scale,
    required this.minScale,
    required this.areaWidth,
    required this.areaHeight,
    required this.zIndex,
    required this.isEnabled,
  });

  factory IslandSlot.fromMap(Map<String, dynamic> m) => IslandSlot(
        slotKey: m["slot_key"] as String,
        label: m["label"] as String?,
        posX: (m["pos_x"] as num?)?.toDouble() ?? 50,
        posY: (m["pos_y"] as num?)?.toDouble() ?? 50,
        scale: (m["scale"] as num?)?.toDouble() ?? 1,
        minScale: (m["min_scale"] as num?)?.toDouble() ?? 0.5,
        areaWidth: (m["area_width"] as num?)?.toDouble() ?? 0,
        areaHeight: (m["area_height"] as num?)?.toDouble() ?? 0,
        zIndex: (m["z_index"] as num?)?.toInt() ?? 0,
        isEnabled: m["is_enabled"] as bool? ?? true,
      );

  bool get isArea => slotKey == "top_11_plus";
  bool get isLastMonth => slotKey == "top_1_last_month";
}

class IslandResident {
  final String id;
  final String displayName;
  final String? profileAvatarUrl;
  final String? avatarMediaUrl;
  final int diamonds;
  final int rank;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;
  final bool muted;
  final double volume;
  final bool loopVideo;
  final String? displayShape;

  const IslandResident({
    required this.id,
    required this.displayName,
    this.profileAvatarUrl,
    this.avatarMediaUrl,
    required this.diamonds,
    required this.rank,
    required this.cropScale,
    required this.cropOffsetX,
    required this.cropOffsetY,
    required this.muted,
    required this.volume,
    required this.loopVideo,
    this.displayShape,
  });

  String get slotKey => rank <= 10 ? "top_$rank" : "top_11_plus";
}

class IslandLastMonthChampion {
  final String streamerId;
  final String displayName;
  final String? avatarUrl;
  final int diamonds;
  final String? avatarMediaUrl;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;
  final bool muted;
  final double volume;
  final bool loopVideo;
  final String? displayShape;

  const IslandLastMonthChampion({
    required this.streamerId,
    required this.displayName,
    this.avatarUrl,
    required this.diamonds,
    this.avatarMediaUrl,
    this.cropScale = 1,
    this.cropOffsetX = 0,
    this.cropOffsetY = 0,
    this.muted = true,
    this.volume = 0,
    this.loopVideo = true,
    this.displayShape,
  });
}

class IslandAvatarOption {
  final String id;
  final String label;
  final String mediaUrl;
  final String? previewImageUrl;
  final int minDiamonds;
  final String? rarity;
  final bool muted;
  final double volume;
  final bool loopVideo;
  final double cropScale;
  final double cropOffsetX;
  final double cropOffsetY;
  final List<String> categoryIds;
  final String? displayShape;
  final String? defaultScope;

  const IslandAvatarOption({
    required this.id,
    required this.label,
    required this.mediaUrl,
    this.previewImageUrl,
    required this.minDiamonds,
    this.rarity,
    required this.muted,
    required this.volume,
    required this.loopVideo,
    required this.cropScale,
    required this.cropOffsetX,
    required this.cropOffsetY,
    required this.categoryIds,
    this.displayShape,
    this.defaultScope,
  });

  factory IslandAvatarOption.fromMap(Map<String, dynamic> m) => IslandAvatarOption(
        id: m["id"] as String,
        label: m["label"] as String? ?? "",
        mediaUrl: m["media_url"] as String? ?? "",
        previewImageUrl: m["preview_image_url"] as String?,
        minDiamonds: (m["min_diamonds"] as num?)?.toInt() ?? 0,
        rarity: m["rarity"] as String?,
        muted: m["muted"] as bool? ?? true,
        volume: (m["volume"] as num?)?.toDouble() ?? 0,
        loopVideo: m["loop_video"] as bool? ?? true,
        cropScale: (m["crop_scale"] as num?)?.toDouble() ?? 1,
        cropOffsetX: (m["crop_offset_x"] as num?)?.toDouble() ?? 0,
        cropOffsetY: (m["crop_offset_y"] as num?)?.toDouble() ?? 0,
        categoryIds: (m["category_ids"] as List?)?.map((e) => e.toString()).toList() ?? const [],
        displayShape: _normalizeDisplayShape(m["display_shape"] as String?),
        defaultScope: m["default_scope"] as String?,
      );
}

/// Configuracao do modo teste (chave `island_test_config` em app_settings).
/// So vale enquanto `island_test_mode` estiver ligado pra agencia.
class IslandTestConfig {
  final int diamondThreshold;
  final String? pinnedTop1;
  final String? pinnedTop2;
  final String? pinnedTop3;
  final Map<String, bool> rarityLocks;

  const IslandTestConfig({
    required this.diamondThreshold,
    this.pinnedTop1,
    this.pinnedTop2,
    this.pinnedTop3,
    required this.rarityLocks,
  });

  factory IslandTestConfig.fromMap(Map<String, dynamic> m) => IslandTestConfig(
        diamondThreshold: (m["diamond_threshold"] as num?)?.toInt() ?? 0,
        pinnedTop1: m["pinned_top1"] as String?,
        pinnedTop2: m["pinned_top2"] as String?,
        pinnedTop3: m["pinned_top3"] as String?,
        rarityLocks: (m["rarity_locks"] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)) ?? const {},
      );
}

/// Tudo que a tela da Ilha Top precisa: fundo (conforme horario), posicoes
/// fixas/area dos slots, quem ocupa cada um (ranking do mes, ao vivo) e o
/// campeao do mes passado. RLS ja restringe tudo ao streamer autenticado /
/// sua propria agencia.
class IslandRepository {
  final _client = Supabase.instance.client;

  /// Resolve o join aninhado streamer_islands(...island_avatars(...)) pro
  /// media_url + config de crop do avatar escolhido. O Supabase retorna o
  /// relacionamento 1:1 ora como Map ora como List (dependendo da FK), entao
  /// isso trata os dois casos antes de devolver o Map do island_avatars.
  Map<String, dynamic>? _extractAvatarInfo(dynamic islandData) {
    Map<String, dynamic>? island;
    if (islandData is List && islandData.isNotEmpty) {
      island = islandData.first as Map<String, dynamic>;
    } else if (islandData is Map) {
      island = islandData as Map<String, dynamic>;
    }

    final avatarData = island?["island_avatars"];
    if (avatarData is Map) {
      return avatarData as Map<String, dynamic>;
    } else if (avatarData is List && avatarData.isNotEmpty) {
      return avatarData.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<({String id, String agencyId, String? categoryId})> _resolveMyProfile() async {
    final authUserId = _client.auth.currentUser!.id;
    final profile = await _client
        .from("profiles")
        .select("id, agency_id, category_id")
        .eq("auth_user_id", authUserId)
        .single();
    return (
      id: profile["id"] as String,
      agencyId: profile["agency_id"] as String,
      categoryId: profile["category_id"] as String?,
    );
  }

  /// `island_test_mode` em app_settings: enquanto ligado, a agencia inteira
  /// entra em modo pre-visualizacao (ninguem e desbloqueado de verdade).
  Future<bool> fetchTestMode() async {
    final me = await _resolveMyProfile();
    final setting = await _client
        .from("app_settings")
        .select("value")
        .eq("agency_id", me.agencyId)
        .eq("key", "island_test_mode")
        .maybeSingle();
    final value = setting?["value"];
    return value == true || value == "true";
  }

  /// `island_test_config` em app_settings: so e relevante quando o modo
  /// teste (acima) esta ligado.
  Future<IslandTestConfig?> fetchTestConfig() async {
    final me = await _resolveMyProfile();
    final setting = await _client
        .from("app_settings")
        .select("value")
        .eq("agency_id", me.agencyId)
        .eq("key", "island_test_config")
        .maybeSingle();
    final value = setting?["value"];
    if (value is Map) return IslandTestConfig.fromMap(value.cast<String, dynamic>());
    return null;
  }

  /// Resolve sozinho a regra de horario + fixo/aleatorio no banco. Se a
  /// agencia ainda nao configurou nenhum fundo, a RPC nao retorna linha.
  Future<IslandBackground?> fetchBackground() async {
    final me = await _resolveMyProfile();
    try {
      final row = await _client
          .rpc("island_pick_background", params: {"p_agency_id": me.agencyId}).single();
      return IslandBackground.fromMap(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<IslandSlot>> fetchSlots() async {
    final me = await _resolveMyProfile();
    final rows = await _client
        .from("island_slots")
        .select("slot_key, label, pos_x, pos_y, scale, min_scale, area_width, area_height, z_index, is_enabled")
        .eq("agency_id", me.agencyId)
        .eq("is_enabled", true);
    return (rows as List).map((r) => IslandSlot.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// `island_max_rank` em app_settings, aba "Posicoes da Ilha": limite total
  /// de streamers exibidos na ilha (fixos + area 11+ juntos), aplicado ja
  /// ordenado por diamantes — quem fica de fora nao aparece em lugar nenhum.
  /// Chave ausente ou valor null = sem limite (comportamento de sempre).
  Future<int?> fetchMaxRank() async {
    final me = await _resolveMyProfile();
    final setting = await _client
        .from("app_settings")
        .select("value")
        .eq("agency_id", me.agencyId)
        .eq("key", "island_max_rank")
        .maybeSingle();
    final value = setting?["value"];
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  /// Ranking do mes (diamantes ao vivo): qualquer streamer ativo que bata o
  /// minimo (80k, ou o diamond_threshold do modo teste) ja aparece na ilha,
  /// automaticamente, ranqueado do maior pro menor. Com modo teste ligado e
  /// posicoes fixadas (pinned_topN), esses streamers ocupam exatamente
  /// aquele top independente dos diamantes deles; o resto preenche as vagas
  /// restantes normalmente, ordenado por diamantes entre si. island_max_rank
  /// corta o total (pinos inclusos) depois de tudo ranqueado.
  ///
  /// Com [periodKey] (ex: "2026-09"), monta a ilha como ficou no fechamento
  /// daquele mes: diamantes do monthly_stats, sem os pinos do modo teste e
  /// incluindo quem ja saiu da agencia. O avatar mostrado e o atual de cada
  /// streamer (o historico de avatares nao e guardado).
  Future<List<IslandResident>> fetchResidents({String? periodKey}) async {
    final me = await _resolveMyProfile();
    final testMode = await fetchTestMode();
    final testConfig = testMode ? await fetchTestConfig() : null;
    final threshold = testConfig?.diamondThreshold ?? 80000;
    final maxRank = await fetchMaxRank();

    final pool = <Map<String, dynamic>>[];
    if (periodKey != null) {
      // mes fechado: resultado final da agencia inteira, com o avatar da ilha
      // com que cada streamer terminou o mes
      final board = await _client.rpc("app_month_board", params: {"p_period": periodKey});
      for (final r in (board as List)) {
        final avatar = r["island_avatar"] is Map ? r["island_avatar"] as Map : null;
        pool.add({
          "id": r["streamer_id"],
          "display_name": r["display_name"],
          "profile_avatar_url": r["avatar_url"],
          "diamonds": (r["diamonds"] as num?)?.toInt() ?? 0,
          "avatar_media_url": avatar?["media_url"],
          "crop_scale": avatar?["crop_scale"],
          "crop_offset_x": avatar?["crop_offset_x"],
          "crop_offset_y": avatar?["crop_offset_y"],
          "muted": avatar?["muted"],
          "volume": avatar?["volume"],
          "loop_video": avatar?["loop_video"],
          "display_shape": avatar?["display_shape"],
        });
      }
    }

    final rows = periodKey != null
        ? const []
        : await _client
            .from("profiles")
            .select(
                "id, display_name, avatar_url, streamer_stats(diamonds), streamer_islands(avatar_id, island_avatars(media_url, crop_scale, crop_offset_x, crop_offset_y, muted, volume, loop_video, display_shape))")
            .eq("agency_id", me.agencyId)
            .eq("is_active", true);
    for (final r in rows) {
      final statsData = r["streamer_stats"];
      int diamonds = 0;
      if (statsData is List && statsData.isNotEmpty) {
        diamonds = statsData.first["diamonds"] as int? ?? 0;
      } else if (statsData is Map) {
        diamonds = statsData["diamonds"] as int? ?? 0;
      }

      final avatar = _extractAvatarInfo(r["streamer_islands"]);

      pool.add({
        "id": r["id"],
        "display_name": r["display_name"],
        "profile_avatar_url": r["avatar_url"],
        "diamonds": diamonds,
        "avatar_media_url": avatar?["media_url"],
        "crop_scale": avatar?["crop_scale"],
        "crop_offset_x": avatar?["crop_offset_x"],
        "crop_offset_y": avatar?["crop_offset_y"],
        "muted": avatar?["muted"],
        "volume": avatar?["volume"],
        "loop_video": avatar?["loop_video"],
        "display_shape": avatar?["display_shape"],
      });
    }

    final byId = {for (final c in pool) c["id"] as String: c};

    // Pinos do modo teste so valem pra ilha ao vivo, nunca pro historico.
    final pins = <int, String>{};
    if (periodKey == null && testConfig != null) {
      if (testConfig.pinnedTop1 != null) pins[1] = testConfig.pinnedTop1!;
      if (testConfig.pinnedTop2 != null) pins[2] = testConfig.pinnedTop2!;
      if (testConfig.pinnedTop3 != null) pins[3] = testConfig.pinnedTop3!;
    }
    final pinnedIds = pins.values.toSet();

    final eligible = pool.where((c) => !pinnedIds.contains(c["id"]) && (c["diamonds"] as int) >= threshold).toList()
      ..sort((a, b) => (b["diamonds"] as int).compareTo(a["diamonds"] as int));

    final ordered = <Map<String, dynamic>>[];
    var ei = 0;
    var rank = 1;
    while (ei < eligible.length || pins.containsKey(rank)) {
      final pinnedId = pins[rank];
      if (pinnedId != null && byId.containsKey(pinnedId)) {
        ordered.add(byId[pinnedId]!);
      } else if (ei < eligible.length) {
        ordered.add(eligible[ei]);
        ei++;
      }
      rank++;
    }

    final limited = maxRank != null && maxRank > 0 ? ordered.take(maxRank).toList() : ordered;

    return [
      for (var i = 0; i < limited.length; i++)
        IslandResident(
          id: limited[i]["id"] as String,
          displayName: limited[i]["display_name"] as String? ?? "Ducker",
          profileAvatarUrl: limited[i]["profile_avatar_url"] as String?,
          avatarMediaUrl: limited[i]["avatar_media_url"] as String?,
          diamonds: limited[i]["diamonds"] as int,
          rank: i + 1,
          cropScale: (limited[i]["crop_scale"] as num?)?.toDouble() ?? 1,
          cropOffsetX: (limited[i]["crop_offset_x"] as num?)?.toDouble() ?? 0,
          cropOffsetY: (limited[i]["crop_offset_y"] as num?)?.toDouble() ?? 0,
          muted: limited[i]["muted"] as bool? ?? true,
          volume: (limited[i]["volume"] as num?)?.toDouble() ?? 0,
          loopVideo: limited[i]["loop_video"] as bool? ?? true,
          displayShape: _normalizeDisplayShape(limited[i]["display_shape"] as String?),
        ),
    ];
  }

  /// Campeao do periodo fechado mais recente (monthly_stats), pra mostrar no
  /// slot especial top_1_last_month. Sempre automatico: nao depende de 80k,
  /// de "Desbloquear ilha" nem do modo teste.
  ///
  /// Com [beforePeriod] (vendo a ilha de um mes passado), pega o campeao do
  /// mes anterior a ele, que era quem estava no banner naquela epoca.
  Future<IslandLastMonthChampion?> fetchTopOfLastMonth({String? beforePeriod}) async {
    final periods = await fetchClosedPeriods();
    final candidates = beforePeriod == null ? periods : periods.where((p) => p.compareTo(beforePeriod) < 0).toList();
    if (candidates.isEmpty) return null;
    final periodKey = candidates.first;

    final board = List<Map<String, dynamic>>.from(
      (await _client.rpc("app_month_board", params: {"p_period": periodKey})) as List,
    )..sort((a, b) => ((b["diamonds"] as num?) ?? 0).compareTo((a["diamonds"] as num?) ?? 0));

    for (final row in board) {
      // o banner e de quem ainda esta na agencia
      if (row["is_active"] != true) continue;
      final avatar = row["island_avatar"] is Map ? row["island_avatar"] as Map : null;
      return IslandLastMonthChampion(
        streamerId: row["streamer_id"] as String,
        displayName: row["display_name"] as String? ?? "Ducker",
        avatarUrl: row["avatar_url"] as String?,
        diamonds: (row["diamonds"] as num?)?.toInt() ?? 0,
        avatarMediaUrl: avatar?["media_url"] as String?,
        cropScale: (avatar?["crop_scale"] as num?)?.toDouble() ?? 1,
        cropOffsetX: (avatar?["crop_offset_x"] as num?)?.toDouble() ?? 0,
        cropOffsetY: (avatar?["crop_offset_y"] as num?)?.toDouble() ?? 0,
        muted: avatar?["muted"] as bool? ?? true,
        volume: (avatar?["volume"] as num?)?.toDouble() ?? 0,
        loopVideo: avatar?["loop_video"] as bool? ?? true,
        displayShape: _normalizeDisplayShape(avatar?["display_shape"] as String?),
      );
    }
    return null;
  }

  /// Meses ja fechados (monthly_stats), do mais recente pro mais antigo,
  /// no formato "AAAA-MM".
  Future<List<String>> fetchClosedPeriods() async {
    // funcao do servidor: a tabela de historico so deixa cada streamer ler a
    // propria linha, entao o app nao enxergava os meses da agencia
    final rows = await _client.rpc("app_month_periods");
    final keys = <String>[];
    for (final r in (rows as List)) {
      final key = r is String ? r : (r as Map).values.first as String?;
      if (key != null && !keys.contains(key)) keys.add(key);
    }
    return keys;
  }

  /// Catalogo de avatares da agencia, ja filtrado pra categoria do streamer
  /// logado (avatares sem category_ids valem pra qualquer categoria). A
  /// ordem vem do sort_order definido no admin (ordem de progressao).
  Future<List<IslandAvatarOption>> fetchAvatarOptions() async {
    final me = await _resolveMyProfile();
    final rows = await _client
        .from("island_avatars")
        .select(
            "id, label, media_url, preview_image_url, min_diamonds, rarity, muted, volume, loop_video, crop_scale, crop_offset_x, crop_offset_y, category_ids, display_shape")
        .eq("agency_id", me.agencyId)
        .eq("is_active", true)
        .order("sort_order");

    return (rows as List)
        .map((r) => IslandAvatarOption.fromMap(r as Map<String, dynamic>))
        .where((opt) => opt.categoryIds.isEmpty || (me.categoryId != null && opt.categoryIds.contains(me.categoryId)))
        .toList();
  }

  /// Resolve os candidatos a avatar padrao (default_scope = 'all' ou
  /// 'category') ja filtrados por agencia/ativo, pra achar tanto o padrao
  /// geral quanto o padrao especifico de categoria sem duas idas ao banco.
  Future<({List<Map<String, dynamic>> rows, String? categoryId})> _fetchDefaultCandidates() async {
    final me = await _resolveMyProfile();
    final rows = await _client
        .from("island_avatars")
        .select(
            "id, label, media_url, preview_image_url, min_diamonds, rarity, muted, volume, loop_video, crop_scale, crop_offset_x, crop_offset_y, category_ids, display_shape, default_scope")
        .eq("agency_id", me.agencyId)
        .eq("is_active", true)
        .inFilter("default_scope", ["all", "category"]);
    return (rows: (rows as List).cast<Map<String, dynamic>>(), categoryId: me.categoryId);
  }

  /// Avatar marcado como padrao no admin, usado como visual de quem ainda
  /// nao escolheu nenhum pato. Prioriza o padrao especifico da categoria do
  /// streamer (default_scope = 'category' + category_ids); se nao houver
  /// nenhum pra essa categoria, cai no padrao geral (default_scope = 'all').
  /// Qualquer erro (coluna faltando etc.) devolve null e quem chamou cai de
  /// volta no emoji de pato — nunca deve derrubar o carregamento da ilha.
  Future<IslandAvatarOption?> fetchDefaultAvatar() async {
    try {
      final candidates = await _fetchDefaultCandidates();
      final chosen = _pickDefaultAvatarRow(candidates.rows, candidates.categoryId);
      if (chosen == null) return null;
      return IslandAvatarOption.fromMap(chosen);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickDefaultAvatarRow(List<Map<String, dynamic>> rows, String? categoryId) {
    Map<String, dynamic>? byCategory;
    Map<String, dynamic>? general;
    for (final r in rows) {
      final scope = r["default_scope"] as String?;
      if (scope == "category" && categoryId != null) {
        final catIds = (r["category_ids"] as List?)?.map((e) => e.toString()).toList() ?? const [];
        if (catIds.contains(categoryId)) byCategory ??= r;
      } else if (scope == "all") {
        general ??= r;
      }
    }
    return byCategory ?? general;
  }

  /// So pra diagnostico temporario: repete a mesma busca do avatar padrao
  /// mas devolve o motivo em texto em vez de engolir o erro, pra aparecer
  /// na propria tela enquanto ajustamos a configuracao no admin.
  Future<String> debugDefaultAvatarStatus() async {
    try {
      final candidates = await _fetchDefaultCandidates();
      final chosen = _pickDefaultAvatarRow(candidates.rows, candidates.categoryId);
      if (chosen == null) {
        return "nenhum avatar ativo com default_scope 'all' ou 'category' compativel encontrado pra essa agencia/categoria";
      }
      return "ok, achou: ${chosen["label"]} (default_scope=${chosen["default_scope"]})";
    } catch (e) {
      return "erro na busca: $e";
    }
  }

  /// Avatar que o streamer escolheu na Ilha Top; se ainda nao escolheu
  /// nenhum, o avatar padrao da agencia/categoria.
  Future<IslandAvatarOption?> fetchMyAvatar() async {
    try {
      final me = await _resolveMyProfile();
      final row = await _client
          .from("streamer_islands")
          .select(
              "island_avatars(id, label, media_url, preview_image_url, min_diamonds, rarity, muted, volume, loop_video, crop_scale, crop_offset_x, crop_offset_y, category_ids, display_shape)")
          .eq("streamer_id", me.id)
          .maybeSingle();
      final info = _extractAvatarInfo(row);
      if (info != null) return IslandAvatarOption.fromMap(info);
    } catch (_) {
      // sem escolha salva / erro de consulta: cai no padrao abaixo
    }
    return fetchDefaultAvatar();
  }

  Future<String?> fetchMyAvatarId() async {
    final me = await _resolveMyProfile();
    final row = await _client
        .from("streamer_islands")
        .select("avatar_id")
        .eq("streamer_id", me.id)
        .maybeSingle();
    return row?["avatar_id"] as String?;
  }

  Future<void> chooseAvatar(String avatarId) async {
    final me = await _resolveMyProfile();
    await _client.from("streamer_islands").upsert(
      {"streamer_id": me.id, "avatar_id": avatarId},
      onConflict: "streamer_id",
    );
  }
}
