/// Conceptos de gasto reutilizables, calculados a partir de los gastos ya registrados.
///
/// "Pago de sueldo", "pago de sueldo" y "Pago de Sueldo  " son el mismo concepto:
/// se agrupan por una clave normalizada y se muestra la escritura más reciente.
library;

import 'package:variedadesjm/modules/gasto/entity/gasto.dart';

class ConceptoGasto {
  const ConceptoGasto({
    required this.nombre,
    required this.veces,
    required this.ultimoMonto,
  });

  /// Escritura más reciente del concepto.
  final String nombre;

  /// Cuántos gastos tienen este concepto.
  final int veces;

  /// Monto del gasto más reciente con este concepto.
  final double ultimoMonto;
}

const _acentos = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n',
};

/// Clave para comparar conceptos: sin mayúsculas, acentos ni espacios repetidos.
String claveConcepto(String texto) {
  final minusculas = texto.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final c in minusculas.split('')) {
    buffer.write(_acentos[c] ?? c);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Conceptos distintos de [gastos], del más usado al menos usado.
/// Con el mismo número de usos, los más recientes van primero.
List<ConceptoGasto> conceptosDe(List<Gasto> gastos) {
  final ordenados = [...gastos]..sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));
  final nombre = <String, String>{};
  final monto = <String, double>{};
  final veces = <String, int>{};
  final orden = <String>[];
  for (final g in ordenados) {
    final clave = claveConcepto(g.descripcion);
    if (clave.isEmpty) continue;
    if (!veces.containsKey(clave)) {
      nombre[clave] = g.descripcion.trim().replaceAll(RegExp(r'\s+'), ' ');
      monto[clave] = g.monto;
      orden.add(clave);
    }
    veces[clave] = (veces[clave] ?? 0) + 1;
  }
  final lista = [
    for (final clave in orden)
      ConceptoGasto(nombre: nombre[clave]!, veces: veces[clave]!, ultimoMonto: monto[clave]!),
  ];
  // sort de Dart no es estable: se desempata por la posición (más reciente primero).
  final posicion = {for (var i = 0; i < lista.length; i++) lista[i].nombre: i};
  lista.sort((a, b) {
    final porUso = b.veces.compareTo(a.veces);
    return porUso != 0 ? porUso : posicion[a.nombre]!.compareTo(posicion[b.nombre]!);
  });
  return lista;
}

/// El concepto de [conceptos] equivalente a [texto], o null si es uno nuevo.
ConceptoGasto? conceptoExistente(String texto, List<ConceptoGasto> conceptos) {
  final clave = claveConcepto(texto);
  if (clave.isEmpty) return null;
  for (final c in conceptos) {
    if (claveConcepto(c.nombre) == clave) return c;
  }
  return null;
}

/// Conceptos cuyo nombre contiene [texto], excluyendo el que ya coincide exactamente.
List<ConceptoGasto> sugerenciasDe(String texto, List<ConceptoGasto> conceptos, {int max = 4}) {
  final clave = claveConcepto(texto);
  if (clave.isEmpty) return const [];
  return [
    for (final c in conceptos)
      if (claveConcepto(c.nombre).contains(clave) && claveConcepto(c.nombre) != clave) c,
  ].take(max).toList();
}
