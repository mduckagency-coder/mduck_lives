import "package:flutter/material.dart";

import "../../../inventory/data/journey_repository.dart";
import "../../../inventory/widgets/constancy_flame.dart";

/// Chama da Constancia na parte de baixo da Home, logo acima do menu.
/// Some enquanto carrega ou se nao houver dados.
class HomeConstancyBar extends StatefulWidget {
  const HomeConstancyBar({super.key});

  @override
  State<HomeConstancyBar> createState() => _HomeConstancyBarState();
}

class _HomeConstancyBarState extends State<HomeConstancyBar> {
  Constancy? _constancy;

  @override
  void initState() {
    super.initState();
    JourneyRepository().fetchConstancy().then((c) {
      if (mounted) setState(() => _constancy = c);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _constancy;
    if (c == null) return const SizedBox.shrink();
    return ConstancyChip(constancy: c);
  }
}
