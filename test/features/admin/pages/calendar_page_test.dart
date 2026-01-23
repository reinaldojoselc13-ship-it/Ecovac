import 'package:ecovac/features/admin/pages/calendar_page.dart';
import 'package:ecovac/features/admin/providers/jornadas_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeJornadasProvider extends JornadasProvider {
  bool loadCountsCalled = false;

  FakeJornadasProvider({List<Map<String, dynamic>>? items}) {
    this.items = items ?? [];
  }

  @override
  Future<void> loadCounts() async {
    loadCountsCalled = true;
    // do not call super to avoid network calls
  }
}

Widget _wrapWithProviders(Widget child, FakeJornadasProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<JornadasProvider>.value(
      value: provider,
      child: child,
    ),
  );
}

void main() {
  group('CalendarPage', () {
    testWidgets('Should call loadCounts on first frame', (tester) async {
      final fake = FakeJornadasProvider();
      await tester.pumpWidget(_wrapWithProviders(const CalendarPage(), fake));
      // allow post frame callback
      await tester.pump();
      expect(fake.loadCountsCalled, isTrue);
    });

    testWidgets('Should render month navigation and change visible month', (tester) async {
      final fake = FakeJornadasProvider();
      await tester.pumpWidget(_wrapWithProviders(const CalendarPage(), fake));

      // initial month text exists
      final monthTextFinder = find.byWidgetPredicate((w) => w is Text && (w.data?.contains('/') ?? false) && w.style?.fontSize == 18);
      expect(monthTextFinder, findsOneWidget);

      // tap next month
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // month text still present after change
      expect(monthTextFinder, findsOneWidget);

      // tap previous month
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(monthTextFinder, findsOneWidget);
    });

    testWidgets('Should show red dot on days with events', (tester) async {
      final today = DateTime.now();
      final key = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final fake = FakeJornadasProvider(items: [
        {'fecha': key, 'nombre': 'Jornada X', 'estado': 'Activa'},
      ]);

      await tester.pumpWidget(_wrapWithProviders(const CalendarPage(), fake));
      await tester.pump();

      // Find a small red circular indicator
      final redDotFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return dec.color == Colors.red && dec.shape == BoxShape.circle && w.constraints == null;
        }
        return false;
      });

      expect(redDotFinder, findsWidgets);
    });

    testWidgets('Should update selected day and list events for that day', (tester) async {
      final base = DateTime.now();
      final selected = DateTime(base.year, base.month, 1);
      final selectedKey = '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      final fake = FakeJornadasProvider(items: [
        {'fecha': selectedKey, 'nombre': 'Campaña', 'estado': 'Programada'},
      ]);

      await tester.pumpWidget(_wrapWithProviders(const CalendarPage(), fake));
      await tester.pump();

      // tap the grid day labeled with selected.day
      await tester.tap(find.text('${selected.day}').first);
      await tester.pump();

      expect(find.textContaining('Eventos en'), findsOneWidget);
      expect(find.text('Campaña'), findsOneWidget);
      expect(find.textContaining('Estado: Programada'), findsOneWidget);
    });

    testWidgets('Should navigate to JornadaFormPage on eye icon pressed', (tester) async {
      final today = DateTime.now();
      final key = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final fake = FakeJornadasProvider(items: [
        {'fecha': key, 'nombre': 'Jornada Y', 'estado': 'Activa'},
      ]);

      await tester.pumpWidget(_wrapWithProviders(const CalendarPage(), fake));
      await tester.pump();

      // Eye icon exists in list tile
      expect(find.byIcon(Icons.remove_red_eye), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove_red_eye));
      await tester.pumpAndSettle();

      // After navigation, there should be a back button in AppBar of pushed route
      expect(find.byType(BackButton), findsOneWidget);
    });
  });
}
