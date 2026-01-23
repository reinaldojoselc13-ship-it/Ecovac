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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
        Text(monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
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
              onTap: hasJ
                  ? () {
                      setState(() => _selectedDay = dt);
                    }
                  : null,
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.green.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(dayIndex.toString(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: hasJ ? Colors.black : Colors.black54)),
              const SizedBox(height: 4),
              if (hasJ) Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            ]),
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
          Text('Jornadas (${list.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (final it in list)
            ListTile(
              title: Text(it['nombre']?.toString() ?? ''),
              subtitle: Text(it['descripcion']?.toString() ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.remove_red_eye),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => JornadaFormPage(initial: it, readOnly: true)));
                },
              ),
            ),
        ]),
      ),
    );
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
      appBar: AppBar(title: const Text('Calendario')),
      body: prov.loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(children: [
                _buildMonthHeader(),
                const SizedBox(height: 8),
                _buildWeekDays(),
                const SizedBox(height: 6),
                _buildCalendarGrid(jornadasByDay),
                const SizedBox(height: 12),
                // Brief description area for the selected day
                Builder(builder: (ctx) {
                  if (_selectedDay == null) return const SizedBox.shrink();
                  final key = '${_selectedDay!.year.toString().padLeft(4, '0')}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}';
                  final list = jornadasByDay[key] ?? [];
                  if (list.isEmpty) return const SizedBox.shrink();
                  final first = list.first;
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('${list.length} jornada${list.length > 1 ? 's' : ''} - ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => showModalBottomSheet(context: context, builder: (ctx) => _buildJornadasForDaySheet(list)),
                            child: const Text('Ver todas'),
                          )
                        ]),
                        const SizedBox(height: 6),
                        Text(first['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(first['descripcion']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => JornadaFormPage(initial: first)));
                            },
                            child: const Text('Ver detalle'),
                          ),
                        ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ]),
            ),
    );
  }
}
