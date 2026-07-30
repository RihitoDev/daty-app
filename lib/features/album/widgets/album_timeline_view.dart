import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../models/album_memory.dart';
import 'memory_card.dart';

class AlbumTimelineView extends StatelessWidget {
  final List<AlbumMemory> memories;

  const AlbumTimelineView({
    super.key,
    required this.memories,
  });

  static const List<String> _monthsFull = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static const List<String> _weekdaysShort = [
    'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'
  ];

  static const List<String> _weekdaysFull = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  String _formatFullDate(DateTime d) {
    final weekday = _weekdaysFull[d.weekday - 1];
    final month = _monthsFull[d.month - 1];
    return '$weekday, ${d.day} de $month de ${d.year}';
  }

  String _getMonthYearHeader(DateTime d) {
    final month = _monthsFull[d.month - 1].toUpperCase();
    return '$month ${d.year}';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Solo':
        return const Color(0xFF64B5F6);
      case 'Pareja':
        return const Color(0xFFF48FB1);
      case 'Grupo':
        return const Color(0xFFCE93D8);
      default:
        return const Color(0xFFB388FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentTheme;

    // Ordenar de más reciente a más antiguo
    final sortedMemories = List<AlbumMemory>.from(memories)
      ..sort((a, b) => b.date.compareTo(a.date));

    // Agrupar por Mes/Año
    final Map<String, List<AlbumMemory>> groupedMemories = {};
    for (final m in sortedMemories) {
      final key = _getMonthYearHeader(m.date);
      groupedMemories.putIfAbsent(key, () => []).add(m);
    }

    final monthKeys = groupedMemories.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      itemCount: monthKeys.length,
      itemBuilder: (context, sectionIndex) {
        final monthKey = monthKeys[sectionIndex];
        final monthMemories = groupedMemories[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera Flotante de Mes/Año (Month Section Header)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: t.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          monthKey,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            t.primary.withValues(alpha: 0.5),
                            t.outline.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Recuerdos dentro del Mes (Opción A: Nodo lateral con día y día de la semana)
            ...monthMemories.asMap().entries.map((entry) {
              final itemIndex = entry.key;
              final memory = entry.value;
              final typeColor = _getTypeColor(memory.type);
              final weekdayShort = _weekdaysShort[memory.date.weekday - 1];
              final dayNum = memory.date.day.toString().padLeft(2, '0');
              final fullDateStr = _formatFullDate(memory.date);
              final isLastInMemoryList =
                  itemIndex == monthMemories.length - 1 &&
                      sectionIndex == monthKeys.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Nodo Lateral Opción A: Día Numérico + Día de la Semana
                    Column(
                      children: [
                        Container(
                          width: 44,
                          height: 48,
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: typeColor,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weekdayShort,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: typeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                dayNum,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: t.text,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLastInMemoryList)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    typeColor.withValues(alpha: 0.6),
                                    t.primary.withValues(alpha: 0.25),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(width: 14),

                    // 2. Tarjeta Ancha de Historia
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: PressableScale(
                          scale: 0.98,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => _MemoryDetailSheetWrapper(
                                memory: memory,
                                theme: t,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: t.card,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: t.outline),
                              boxShadow: [
                                BoxShadow(
                                  color: t.shadow,
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Imagen de Portada de la Historia
                                if (memory.photoUrls.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FullScreenImageViewer(
                                            imageUrl: memory.photoUrls.first,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      height: 175,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(22),
                                        ),
                                        color: t.isDark
                                            ? Colors.grey.shade900
                                            : Colors.grey.shade200,
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                          top: Radius.circular(22),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: memory.photoUrls.first,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Center(
                                                child: CircularProgressIndicator(
                                                  color: t.primary,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) => Icon(
                                                  Icons.broken_image_outlined,
                                                  color: t.muted),
                                            ),
                                            if (memory.photoUrls.length > 1)
                                              Positioned(
                                                top: 10,
                                                right: 10,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 9,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .collections_rounded,
                                                          size: 12,
                                                          color: Colors.white),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${memory.photoUrls.length}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Información del Recuerdo con Fecha Completa
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: typeColor
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              memory.type.toUpperCase(),
                                              style: TextStyle(
                                                color: typeColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              fullDateStr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: t.muted,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${memory.emoji} ${memory.title}',
                                        style: TextStyle(
                                          color: t.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (memory.reviews.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          memory.reviews.first,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: t.text2,
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MemoryDetailSheetWrapper extends StatelessWidget {
  final AlbumMemory memory;
  final AppCustomTheme theme;

  const _MemoryDetailSheetWrapper({
    required this.memory,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return MemoryCard(memory: memory).buildDetailSheet(context, theme);
  }
}
