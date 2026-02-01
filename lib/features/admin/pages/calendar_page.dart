import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'jornada_form_page.dart';

class CalendarPage extends StatefulWidget {
  final DateTime? initialSelected;
  const CalendarPage({super.key, this.initialSelected});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _displayedMonth = DateTime.now();
  DateTime? _selectedDay;

  void _prevMonth() => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1));
  void _nextMonth() => setState(() => _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1));

  Map<String, List<Map<String, dynamic>>> _groupedByDay(List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final it in items) {
      final fecha = (it['fecha'] ?? '').toString();
      if (fecha.isEmpty) continue;
      DateTime? dt;
      try {
        dt = DateTime.parse(fecha);
      } catch (_) {
        continue;
      }
      final key = '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
      map.putIfAbsent(key, () => []).add(it);
    }
    return map;
  }

  Widget _buildMonthHeader() {
    final monthLabel = '${_displayedMonth.year} - ${_displayedMonth.month.toString().padLeft(2, '0')}';
    return Column(
      children: [
        // Header title with green accent line
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            children: [
              Text(
                'Calendario',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Emerald Green
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Color(0xFF10B981)),
              onPressed: _prevMonth,
            ),
            Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Color(0xFF10B981)),
              onPressed: _nextMonth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekDays() {
    const names = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: names.map((n) => Expanded(child: Center(child: Text(n, style: const TextStyle(fontWeight: FontWeight.bold))))).toList(),
    );
  }

  Widget _buildCalendarGrid(Map<String, List<Map<String, dynamic>>> jornadasByDay) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday; // 1 = Mon
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final totalCells = ((firstWeekday - 1) + daysInMonth);
    final rows = (totalCells / 7).ceil();

    final cells = <Widget>[];
    for (var i = 0; i < rows * 7; i++) {
      final dayIndex = i - (firstWeekday - 1) + 1;
      if (dayIndex < 1 || dayIndex > daysInMonth) {
        cells.add(const Expanded(child: SizedBox.shrink()));
        continue;
      }
      final dt = DateTime(year, month, dayIndex);
      final key = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final hasJ = jornadasByDay.containsKey(key);
      final selected = _selectedDay != null && _selectedDay!.year == dt.year && _selectedDay!.month == dt.month && _selectedDay!.day == dt.day;

      cells.add(Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _selectedDay = dt);
          },
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
              border: selected
                  ? Border.all(color: const Color(0xFF10B981), width: 1.5)
                  : Border.all(color: Colors.grey.shade200, width: 0.5),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF10B981) : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayIndex.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: selected
                            ? Colors.white
                            : (hasJ ? Colors.black87 : Colors.black38),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasJ)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.6),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    // Build rows
    final rowWidgets = <Widget>[];
    for (var r = 0; r < rows; r++) {
      final start = r * 7;
      final end = start + 7;
      rowWidgets.add(Row(children: cells.sublist(start, end)));
    }

    return Column(children: rowWidgets);
  }

  Widget _buildJornadasForDaySheet(List<Map<String, dynamic>> list) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Jornadas del día (${list.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (final it in list)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            it['nombre']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye, size: 20),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => JornadaFormPage(initial: it, readOnly: true),
                            ));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(it['descripcion']?.toString() ?? 'Sin descripción', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    
                    // Mostrar hora si está disponible
                    if (it['fecha'] != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(it['fecha'].toString()),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    // Mostrar ubicación si está disponible
                    if (it['ubicacion']?.toString().isNotEmpty == true) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              it['ubicacion'].toString(),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    // Mostrar veterinarios asignados
                    if (it['staff_ids'] != null && (it['staff_ids'] as List).isNotEmpty) ...[
                      const Text('Personal asignado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${(it['staff_ids'] as List).length} miembro(s) asignado(s)',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                    ],
                    
                    // Mostrar vacunas asignadas
                    if (it['vacunas'] != null && (it['vacunas'] as List).isNotEmpty) ...[
                      const Text('Vacunas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${(it['vacunas'] as List).length} lote(s) asignado(s)',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Hora no disponible';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<JornadasProvider>();
      prov.loadCounts();
      // Ensure realtime subscription is active so calendar updates when jornadas change
      prov.startRealtime();
      // honor optional initial selection
      if (widget.initialSelected != null) {
        _selectedDay = DateTime(widget.initialSelected!.year, widget.initialSelected!.month, widget.initialSelected!.day);
        _displayedMonth = DateTime(_selectedDay!.year, _selectedDay!.month);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<JornadasProvider>();
    final jornadasByDay = _groupedByDay(prov.items.cast<Map<String, dynamic>>());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: prov.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header con flecha de regreso
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF10B981)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: _buildMonthHeader(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(children: [
                        const SizedBox(height: 8),
                        _buildWeekDays(),
                        const SizedBox(height: 6),
                        _buildCalendarGrid(jornadasByDay),
                        const SizedBox(height: 12),
                        // Footer card for selected day
                        Builder(builder: (ctx) {
                          if (_selectedDay == null) return const SizedBox.shrink();
                          final key = '${_selectedDay!.year.toString().padLeft(4, '0')}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
                          final list = jornadasByDay[key] ?? [];
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0),
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3748), // Dark gray card
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Día de Vacunación',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: list.isNotEmpty ? const Color(0xFF10B981) : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_selectedDay!.day.toString().padLeft(2, '0')}/${_selectedDay!.month.toString().padLeft(2, '0')}/${_selectedDay!.year}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (list.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${list.length} jornada${list.length > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                                if (list.isEmpty) ...[
                                  // No jornadas message
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.event_busy,
                                          color: Colors.white.withOpacity(0.6),
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No hay jornadas disponibles',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // Jornada details
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Color(0xFF10B981),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Centro Hospitalario',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              list.first['ubicacion']?.toString() ?? 'Centro no especificado',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Time pill tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          list.first['fecha'] != null
                                              ? 'Hora: ${_formatDateTime(list.first['fecha'].toString())}'
                                              : 'Hora: No especificada',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Action buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            builder: (ctx) => _buildJornadasForDaySheet(list),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF10B981)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Ver todas',
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => JornadaFormPage(initial: list.first),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text(
                                            'Ver detalles',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
