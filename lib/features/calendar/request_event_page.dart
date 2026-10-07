import "package:flutter/material.dart";
import "data/calendar_requests_repository.dart";
import "my_requests_page.dart";

enum _Step { chooseType, battle, event }

class RequestEventPage extends StatefulWidget {
  const RequestEventPage({super.key});

  @override
  State<RequestEventPage> createState() => _RequestEventPageState();
}

class _RequestEventPageState extends State<RequestEventPage> {
  final _repository = CalendarRequestsRepository();
  late Future<List<RequestPromptItem>> _promptsFuture;

  _Step _step = _Step.chooseType;
  String? _fulfillingPromptId;

  DateTime? _date;
  String? _startTime;
  int _rounds = 1;
  final _diamondsController = TextEditingController();
  String? _opponentType;
  bool _needsBanner = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TimeOfDay? _eventTime;

  bool _submitting = false;

  static const _battleTimeSlots = ["17:00", "18:00", "19:00", "20:00", "21:00", "22:00", "23:00", "00:00"];
  static const _purple = Color(0xFFB026FF);
  static const _purpleDark = Color(0xFF7A0BD4);
  static const _bg = Color(0xFF1A0B2E);

  @override
  void initState() {
    super.initState();
    _promptsFuture = _repository.fetchPendingPrompts();
    _diamondsController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _diamondsController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startBattleFlow({RequestPromptItem? prompt}) {
    setState(() {
      _fulfillingPromptId = prompt?.id;
      _date = prompt?.suggestedDateStart;
      _step = _Step.battle;
    });
  }

  void _startEventFlow({RequestPromptItem? prompt}) {
    setState(() {
      _fulfillingPromptId = prompt?.id;
      _date = prompt?.suggestedDateStart;
      _step = _Step.event;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: (_date != null && !_date!.isBefore(today)) ? _date! : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _purple, surface: _bg)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickEventTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _purple, surface: _bg)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  bool get _battleValid =>
      _date != null && _startTime != null && _opponentType != null && (int.tryParse(_diamondsController.text.trim()) ?? 0) > 0;

  bool get _eventValid => _date != null && _eventTime != null && _titleController.text.trim().isNotEmpty;

  Future<void> _submitBattle() async {
    if (!_battleValid || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _repository.submitBattleRequest(
        date: _date!,
        startTime: "$_startTime:00",
        rounds: _rounds,
        diamondsEstimate: int.tryParse(_diamondsController.text.trim()) ?? 0,
        opponentType: _opponentType!,
        needsBanner: _needsBanner,
        fulfillsPromptId: _fulfillingPromptId,
      );
      if (!mounted) return;
      _showSuccessAndClose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar solicitacao: $e")));
      setState(() => _submitting = false);
    }
  }

  Future<void> _submitEvent() async {
    if (!_eventValid || _submitting) return;
    setState(() => _submitting = true);
    try {
      final t = _eventTime!;
      final timeStr = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00";
      await _repository.submitEventRequest(
        date: _date!,
        startTime: timeStr,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        needsBanner: _needsBanner,
        fulfillsPromptId: _fulfillingPromptId,
      );
      if (!mounted) return;
      _showSuccessAndClose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar solicitacao: $e")));
      setState(() => _submitting = false);
    }
  }

  void _showSuccessAndClose() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Solicitacao enviada!", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Sua solicitacao foi enviada para a agencia. Voce vai receber um alerta assim que ela for avaliada.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("OK", style: TextStyle(color: _purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _Step.chooseType) {
              Navigator.of(context).pop();
            } else {
              setState(() => _step = _Step.chooseType);
            }
          },
        ),
        title: Text(_titleForStep(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: switch (_step) {
        _Step.chooseType => _buildChooseType(),
        _Step.battle => _buildBattleForm(),
        _Step.event => _buildEventForm(),
      },
    );
  }

  String _titleForStep() {
    switch (_step) {
      case _Step.battle:
        return "Batalha Oficial";
      case _Step.event:
        return "Meu Evento";
      case _Step.chooseType:
        return "Nova Solicitacao";
    }
  }

  Widget _buildChooseType() {
    return FutureBuilder<List<RequestPromptItem>>(
      future: _promptsFuture,
      builder: (context, snapshot) {
        final prompts = snapshot.data ?? const [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prompts.isNotEmpty) ...[
                const Text("Pedidos da agencia", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...prompts.map(_promptCard),
                const SizedBox(height: 20),
              ],
              const Text("O que voce quer solicitar?", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _typeCard(
                emoji: "⚔️",
                title: "Batalha Oficial",
                subtitle: "Dia, horario, diamantes estimados e oponente.",
                onTap: () => _startBattleFlow(),
              ),
              const SizedBox(height: 12),
              _typeCard(
                emoji: "🎉",
                title: "Meu Evento",
                subtitle: "Dia, horario, titulo e descricao do seu evento.",
                onTap: () => _startEventFlow(),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyRequestsPage())),
                  icon: const Icon(Icons.receipt_long, color: Colors.white54, size: 18),
                  label: const Text("Ver minhas solicitacoes", style: TextStyle(color: Colors.white54)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _promptCard(RequestPromptItem prompt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => prompt.type == RequestType.batalhaOficial ? _startBattleFlow(prompt: prompt) : _startEventFlow(prompt: prompt),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_purple.withOpacity(0.3), _purpleDark.withOpacity(0.3)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _purple.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(prompt.message, style: const TextStyle(color: Colors.white, fontSize: 12))),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeCard({required String emoji, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _alertBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFD700), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Esta solicitacao precisa ser confirmada pela agencia antes de entrar no seu calendario.",
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _dateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
            const SizedBox(width: 10),
            Text(
              _date != null
                  ? "${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}"
                  : "Selecionar data",
              style: TextStyle(color: _date != null ? Colors.white : Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [_purple, _purpleDark]) : null,
          color: selected ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : Colors.white.withOpacity(0.15)),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _bannerSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Expanded(child: Text("Precisa de banner para divulgacao?", style: TextStyle(color: Colors.white, fontSize: 12.5))),
          Switch(value: _needsBanner, activeColor: _purple, onChanged: (v) => setState(() => _needsBanner = v)),
        ],
      ),
    );
  }

  Widget _submitButton(String label, bool valid, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: valid && !_submitting ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purple,
          disabledBackgroundColor: Colors.white12,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _submitting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBattleForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _alertBox(),
          _fieldLabel("Dia"),
          _dateField(),
          _fieldLabel("Horario (entre 17h e 00h)"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _battleTimeSlots.map((t) => _chip(t, _startTime == t, () => setState(() => _startTime = t))).toList(),
          ),
          _fieldLabel("Formato"),
          Row(
            children: [
              _chip("Melhor de 1", _rounds == 1, () => setState(() => _rounds = 1)),
              const SizedBox(width: 8),
              _chip("Melhor de 3", _rounds == 3, () => setState(() => _rounds = 3)),
            ],
          ),
          _fieldLabel("Diamantes estimados"),
          TextField(
            controller: _diamondsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Ex: 5000",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          _fieldLabel("Oponente"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip("Agencia", _opponentType == "agencia", () => setState(() => _opponentType = "agencia")),
              _chip("Externo", _opponentType == "externo", () => setState(() => _opponentType = "externo")),
              _chip("Tanto faz", _opponentType == "tanto_faz", () => setState(() => _opponentType = "tanto_faz")),
            ],
          ),
          const SizedBox(height: 16),
          _bannerSwitch(),
          const SizedBox(height: 24),
          _submitButton("Enviar solicitacao", _battleValid, _submitBattle),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEventForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _alertBox(),
          _fieldLabel("Dia"),
          _dateField(),
          _fieldLabel("Horario"),
          GestureDetector(
            onTap: _pickEventTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white54, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    _eventTime != null ? _eventTime!.format(context) : "Selecionar horario",
                    style: TextStyle(color: _eventTime != null ? Colors.white : Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          _fieldLabel("Titulo"),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Nome do evento",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          _fieldLabel("Descricao (opcional)"),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Detalhes do evento",
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          _bannerSwitch(),
          const SizedBox(height: 24),
          _submitButton("Enviar solicitacao", _eventValid, _submitEvent),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
