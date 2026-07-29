import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../album/models/album_memory.dart';
import '../../album/providers/album_provider.dart';
import '../../album/widgets/memory_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  // Colores por tipo — iguales a MemoryCard.
  static const _soloColor = Color(0xFF1976D2);
  static const _coupleColor = Color(0xFFC2185B);
  static const _groupColor = Color(0xFF8E24AA);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Map<DateTime, List<AlbumMemory>> _groupByDay(
          List<AlbumMemory> memories) {
    final map = <DateTime, List<AlbumMemory>>{};
    for (final m in memories) {
      final day = _normalize(m.date);
      map.putIfAbsent(day, () => []).add(m);
    }
    return map;
  }

  IconData _typeIcon(String type) => switch (type) {
        'Solo' => Icons.person_outline,
        'Pareja' => Icons.favorite_outline,
        'Grupo' => Icons.groups_rounded,
        _ => Icons.auto_awesome,
      };

  Color _typeColor(String type) => switch (type) {
        'Solo' => _soloColor,
        'Pareja' => _coupleColor,
        'Grupo' => _groupColor,
        _ => const Color(0xFF9C27B0),
      };

  void _goToMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(
          _focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  String _formatMonthYear(DateTime d) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final provider = context.watch<AlbumProvider>();

    return Scaffold(
      backgroundColor: customTheme.bg,
      body: StreamBuilder<List<AlbumMemory>>(
        stream: provider.allStream,
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final errorMessage = hasError ? snapshot.error.toString() : null;
          final memories = snapshot.data ?? [];

          final grouped = _groupByDay(memories);
          // Cuenta eventos del mes enfocado.
          final monthEvents = memories.where((m) {
            final d = m.date;
            return d.year == _focusedMonth.year &&
                d.month == _focusedMonth.month;
          }).length;

          final selectedMemories = _selectedDay != null
              ? (grouped[_selectedDay!] ?? [])
              : <AlbumMemory>[];

          return SafeArea(
            child: Column(
              children: [
                _buildAppBar(customTheme),
                if (isLoading)
                  LinearProgressIndicator(
                    color: customTheme.primary,
                    backgroundColor: Colors.transparent,
                    minHeight: 3,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 10, 16, 30),
                    child: Column(
                      children: [
                        _buildMonthHeader(
                            customTheme, monthEvents),
                        const SizedBox(height: 10),
                        _buildWeekdayHeader(customTheme),
                        const SizedBox(height: 4),
                        _buildCalendarGrid(
                            customTheme, grouped),
                        const SizedBox(height: 20),
                        if (hasError && errorMessage != null) ...[
                          _buildErrorBanner(customTheme, errorMessage),
                          const SizedBox(height: 10),
                        ],
                        _buildDayDetail(
                            customTheme, selectedMemories),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(AppCustomTheme t, String errorMessage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Detalle del Error de Consulta',
                  style: TextStyle(
                    color: t.isDark ? Colors.red.shade300 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            errorMessage,
            style: TextStyle(
              color: t.isDark ? Colors.red.shade200 : Colors.red.shade900,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────

  Widget _buildAppBar(AppCustomTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          PressableScale(
            scale: 0.92,
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.elevatedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.outline),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: t.text, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Calendario',
                style: TextStyle(
                    color: t.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ── Mes ──────────────────────────────────────────────────────────

  Widget _buildMonthHeader(AppCustomTheme t, int monthEvents) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: t.elevatedSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.outline),
            boxShadow: [
              BoxShadow(
                  color: t.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
              if (t.isDark)
                BoxShadow(
                    color: t.primary.withValues(alpha: 0.07),
                    blurRadius: 22,
                    spreadRadius: -5),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PressableScale(
                scale: 0.88,
                onTap: () => _goToMonth(-1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.primaryLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.chevron_left_rounded,
                      color: t.primary, size: 22),
                ),
              ),
              Column(
                children: [
                  Text(_formatMonthYear(_focusedMonth),
                      style: TextStyle(
                          color: t.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  if (monthEvents > 0)
                    Text(
                      '$monthEvents ${monthEvents == 1 ? 'aventura' : 'aventuras'} este mes',
                      style: TextStyle(
                          color: t.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              PressableScale(
                scale: 0.88,
                onTap: () => _goToMonth(1),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.primaryLight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.chevron_right_rounded,
                      color: t.primary, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Días de la semana ───────────────────────────────────────────

  Widget _buildWeekdayHeader(AppCustomTheme t) {
    const weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: weekdays
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: TextStyle(
                            color: t.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Grid del calendario ─────────────────────────────────────────

  Widget _buildCalendarGrid(
    AppCustomTheme t,
    Map<DateTime, List<AlbumMemory>> grouped,
  ) {
    final firstOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Lun=1

    final today = _normalize(DateTime.now());
    final cells = <Widget>[];

    // Huecos para alinear.
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final cellDate =
          DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dayMemories = grouped[cellDate] ?? [];
      final isToday = cellDate == today;
      final isSelected = cellDate == _selectedDay;
      final hasEvents = dayMemories.isNotEmpty;

      // Tipos únicos del día.
      final presentTypes =
          dayMemories.map((m) => m.type).toSet().toList();

      cells.add(
        PressableScale(
          scale: 0.92,
          onTap: () => setState(() => _selectedDay = cellDate),
          child: Container(
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // Día seleccionado: gradiente primario.
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [t.primary, t.primaryDark],
                    )
                  : null,
              // Día hoy sin seleccionar: fondo sutil + borde.
              color: isToday && !isSelected
                  ? t.primaryLight.withValues(alpha: 0.3)
                  : (hasEvents
                      ? t.elevatedSurface
                      : Colors.transparent),
              border: isToday && !isSelected
                  ? Border.all(
                      color: t.primary.withValues(alpha: 0.6),
                      width: 1.5)
                  : (hasEvents
                      ? Border.all(
                          color: t.outline,
                          width: 0.5)
                      : null),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color:
                              t.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ]
                  : (hasEvents
                      ? [
                          BoxShadow(
                              color: t.shadow,
                              blurRadius: 8,
                              offset: const Offset(0, 3)),
                        ]
                      : null),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Número del día.
                Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isToday
                            ? t.primary
                            : t.text),
                    fontWeight: isToday || isSelected
                        ? FontWeight.w900
                        : FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                // Iconos por tipo de aventura.
                if (hasEvents)
                  SizedBox(
                    height: 14,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 0,
                      children: presentTypes
                          .take(2)
                          .map((type) => Icon(
                                _typeIcon(type),
                                size: 10,
                                color: isSelected
                                    ? Colors.white.withValues(
                                        alpha: 0.85)
                                    : _typeColor(type),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: t.elevatedSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.outline),
            boxShadow: [
              BoxShadow(
                  color: t.shadow,
                  blurRadius: 22,
                  offset: const Offset(0, 8)),
              if (t.isDark)
                BoxShadow(
                    color: t.primary.withValues(alpha: 0.07),
                    blurRadius: 24,
                    spreadRadius: -5),
            ],
          ),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            padding: const EdgeInsets.all(4),
            children: cells,
          ),
        ),
      ),
    );
  }

  // ── Detalle del día ────────────────────────────────────────────

  Widget _buildDayDetail(
    AppCustomTheme t,
    List<AlbumMemory> memories,
  ) {
    if (_selectedDay == null) return const SizedBox.shrink();

    final dateStr = _formatDay(_selectedDay!);

    if (memories.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: t.elevatedSurface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.outline),
              boxShadow: [
                BoxShadow(
                    color: t.shadow,
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_outlined,
                    size: 40, color: t.muted),
                const SizedBox(height: 10),
                Text(
                  'Sin recuerdos el $dateStr',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'No hay aventuras registradas en esta fecha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: t.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Recuerdos del $dateStr (${memories.length})',
                style: TextStyle(
                  color: t.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        ...memories.map(
          (m) => MemoryCard(
            memory: m,
            cardHeight: 230,
          ),
        ),
      ],
    );
  }
}
