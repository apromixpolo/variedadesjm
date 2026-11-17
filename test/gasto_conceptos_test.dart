import 'package:flutter_test/flutter_test.dart';
import 'package:variedadesjm/modules/gasto/entity/gasto.dart';
import 'package:variedadesjm/modules/gasto/service/gasto_conceptos.dart';

Gasto g(String id, String desc, double monto, DateTime fecha) => Gasto(
      id: id,
      descripcion: desc,
      monto: monto,
      fechaGasto: fecha,
      idCategoriaGasto: 'general',
      metodoPago: 'Efectivo',
    );

void main() {
  test('mayúsculas, acentos y espacios no crean conceptos distintos', () {
    expect(claveConcepto('  Pago  de SUELDO '), claveConcepto('pago de sueldo'));
    expect(claveConcepto('Energía'), claveConcepto('energia'));
  });

  test('agrupa conceptos, usa la escritura y el monto más recientes', () {
    final conceptos = conceptosDe([
      g('1', 'pago de sueldo', 300, DateTime(2026, 10, 1)),
      g('2', 'Pago de Sueldo', 350, DateTime(2026, 11, 1)),
      g('3', 'Uber', 5, DateTime(2026, 11, 2)),
    ]);
    expect(conceptos.length, 2);
    expect(conceptos.first.nombre, 'Pago de Sueldo');
    expect(conceptos.first.veces, 2);
    expect(conceptos.first.ultimoMonto, 350);
  });

  test('conceptoExistente y sugerencias', () {
    final conceptos = conceptosDe([
      g('1', 'Pago de Sueldo', 300, DateTime(2026, 10, 1)),
      g('2', 'Pago de luz', 40, DateTime(2026, 10, 2)),
    ]);
    expect(conceptoExistente('pago de sueldo', conceptos)!.nombre, 'Pago de Sueldo');
    expect(conceptoExistente('Internet', conceptos), isNull);
    expect(sugerenciasDe('pago', conceptos).length, 2);
    expect(sugerenciasDe('pago de luz', conceptos), isEmpty);
  });
}
