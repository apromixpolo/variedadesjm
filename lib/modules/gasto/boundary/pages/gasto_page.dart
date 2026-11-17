/// Pantalla de gastos: registro rápido arriba y lista de lo ya registrado.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:variedadesjm/controllers/database/sembast_stores.dart';
import 'package:variedadesjm/controllers/providers/sembast_core_providers.dart';
import 'package:variedadesjm/modules/gasto/entity/gasto.dart';
import 'package:variedadesjm/modules/gasto/service/gasto_conceptos.dart';
import 'package:variedadesjm/shared/data/app_data_provider.dart';
import 'package:variedadesjm/shared/data/app_record_writer.dart';
import 'package:variedadesjm/shared/layouts/app_layout.dart';
import 'package:variedadesjm/shared/themes/colors.dart';
import 'package:variedadesjm/shared/utils/format.dart';
import 'package:variedadesjm/shared/widgets/pagination/app_pagination.dart';

enum _Period { hoy, mes, todos }

const _pageSize = 10;

/// Cuántos conceptos se muestran como atajos antes de "Ver todos".
const _conceptosVisibles = 8;

/// Registra gastos con atajos frecuentes y muestra el historial por período.
class GastoPage extends ConsumerStatefulWidget {
  const GastoPage({super.key});

  @override
  ConsumerState<GastoPage> createState() => _GastoPageState();
}

class _GastoPageState extends ConsumerState<GastoPage> {
  static const _frequent = [
    ('Comida', Icons.restaurant_outlined),
    ('Uber', Icons.directions_car_outlined),
    ('Gasolina', Icons.local_gas_station_outlined),
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _descriptionFocus = FocusNode();
  final _amountFocus = FocusNode();
  String _payment = 'Efectivo';
  _Period _period = _Period.hoy;
  bool _saving = false;
  int _page = 1;

  // Los conceptos solo se recalculan cuando cambia la lista de gastos.
  List<Gasto>? _gastosCache;
  List<ConceptoGasto> _conceptosCache = const [];

  List<ConceptoGasto> _conceptos(List<Gasto> gastos) {
    if (!identical(gastos, _gastosCache)) {
      _gastosCache = gastos;
      _conceptosCache = conceptosDe(gastos);
    }
    return _conceptosCache;
  }

  /// Rellena el concepto y deja el cursor en el monto para escribir solo la cantidad.
  void _usarConcepto(String nombre) {
    setState(() => _description.text = nombre);
    FocusScope.of(context).requestFocus(_amountFocus);
  }

  /// Hoja con todos los conceptos y un buscador, para elegir uno.
  Future<void> _verTodosLosConceptos(List<ConceptoGasto> conceptos) async {
    final elegido = await showModalBottomSheet<ConceptoGasto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ConceptosSheet(conceptos: conceptos),
    );
    if (elegido != null) _usarConcepto(elegido.nombre);
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _descriptionFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final database = await ref.read(sembastDatabaseProvider.future);
      // Si el concepto ya existe (aunque cambien mayúsculas o acentos) se usa su escritura.
      final existente = conceptoExistente(
          _description.text, _conceptos(ref.read(gastosProvider).valueOrNull ?? const []));
      final gasto = Gasto(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        descripcion: existente?.nombre ?? _description.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        monto: double.parse(_amount.text.trim().replaceAll(',', '.')),
        fechaGasto: DateTime.now(),
        idCategoriaGasto: 'general',
        metodoPago: _payment,
      );
      await writeRecord(
        database: database,
        storeName: SembastStores.gasto,
        id: gasto.id,
        value: gasto.toMap(),
      );
      ref
        ..invalidate(gastosProvider)
        ..invalidate(dashboardDataProvider);
      _description.clear();
      _amount.clear();
      _page = 1;
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Gasto registrado: ${money(gasto.monto)}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final database = await ref.read(sembastDatabaseProvider.future);
    await deleteRecord(database: database, storeName: SembastStores.gasto, id: id);
    ref
      ..invalidate(gastosProvider)
      ..invalidate(dashboardDataProvider);
  }

  bool _inPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.hoy:
        return sameDay(date, now);
      case _Period.mes:
        return date.year == now.year && date.month == now.month;
      case _Period.todos:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(gastosProvider);
    return AppLayout(
      currentIndex: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          Text('Gastos',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: scheme.primary)),
          const Text('Controla el flujo de efectivo de tu negocio'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Gastos frecuentes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text('Un toque y listo', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final item in _frequent)
                _QuickExpense(
                  label: item.$1,
                  icon: item.$2,
                  onTap: () {
                    setState(() => _description.text = item.$1);
                    FocusScope.of(context).requestFocus(_descriptionFocus);
                  },
                ),
              _QuickExpense(
                label: 'Otro',
                icon: Icons.add_rounded,
                outlined: true,
                onTap: () {
                  setState(() => _description.clear());
                  FocusScope.of(context).requestFocus(_descriptionFocus);
                },
              ),
            ],
          ),
          ..._seccionConceptos(context, state.valueOrNull ?? const []),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Nuevo gasto',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('Se guarda con la fecha de hoy',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _description,
                            focusNode: _descriptionFocus,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(labelText: 'Concepto'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Ingresa un concepto'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _amount,
                            focusNode: _amountFocus,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Monto',
                              prefixText: '\$ ',
                              helperText: _ultimoMontoTexto(state.valueOrNull ?? const []),
                            ),
                            validator: (value) {
                              final amount = double.tryParse((value ?? '').replaceAll(',', '.'));
                              return amount == null || amount <= 0 ? 'Monto inválido' : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    ..._sugerencias(state.valueOrNull ?? const []),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final method in const ['Efectivo', 'Transferencia', 'Tarjeta'])
                          ChoiceChip(
                            label: Text(method),
                            selected: _payment == method,
                            onSelected: (_) => setState(() => _payment = method),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'Guardando...' : 'Registrar gasto'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hoy'),
                selected: _period == _Period.hoy,
                onSelected: (_) => setState(() {
                  _period = _Period.hoy;
                  _page = 1;
                }),
              ),
              ChoiceChip(
                label: const Text('Este mes'),
                selected: _period == _Period.mes,
                onSelected: (_) => setState(() {
                  _period = _Period.mes;
                  _page = 1;
                }),
              ),
              ChoiceChip(
                label: const Text('Todos'),
                selected: _period == _Period.todos,
                onSelected: (_) => setState(() {
                  _period = _Period.todos;
                  _page = 1;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Text('No se pudieron cargar los gastos: $error'),
            data: (all) {
              final gastos = all.where((g) => _inPeriod(g.fechaGasto)).toList()
                ..sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));
              final total = gastos.fold<double>(0, (sum, g) => sum + g.monto);
              // Solo se dibujan los 10 gastos de la página actual.
              final pages = gastos.isEmpty ? 1 : (gastos.length / _pageSize).ceil();
              final page = _page > pages ? pages : _page;
              final visibles = gastos.skip((page - 1) * _pageSize).take(_pageSize).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          switch (_period) {
                            _Period.hoy => 'Gastos de hoy',
                            _Period.mes => 'Gastos del mes',
                            _Period.todos => 'Todos los gastos',
                          },
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('Total ${money(total)}',
                          style: const TextStyle(
                              color: AppColors.danger, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: gastos.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text('No hay gastos en este período.'),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < visibles.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.danger.withValues(alpha: .12),
                                    foregroundColor: AppColors.danger,
                                    child: const Icon(Icons.receipt_long_outlined, size: 17),
                                  ),
                                  title: Text(visibles[i].descripcion),
                                  subtitle: Text(
                                      '${shortDate(visibles[i].fechaGasto)} · ${visibles[i].metodoPago}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('-${money(visibles[i].monto)}',
                                          style: const TextStyle(
                                              color: AppColors.danger,
                                              fontWeight: FontWeight.w800)),
                                      IconButton(
                                        tooltip: 'Eliminar',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        onPressed: () => _delete(visibles[i].id),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  if (gastos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: AppPagination(
                        currentPage: page,
                        totalItems: gastos.length,
                        pageSize: _pageSize,
                        itemName: 'gastos',
                        onPageChanged: (value) => setState(() => _page = value),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Texto de ayuda bajo el monto: cuánto costó la última vez este concepto.
  String? _ultimoMontoTexto(List<Gasto> gastos) {
    final concepto = conceptoExistente(_description.text, _conceptos(gastos));
    return concepto == null ? null : 'Última vez: ${money(concepto.ultimoMonto)}';
  }

  /// Sugerencias mientras se escribe, para no repetir un concepto ya creado.
  List<Widget> _sugerencias(List<Gasto> gastos) {
    final sugeridos = sugerenciasDe(_description.text, _conceptos(gastos));
    if (sugeridos.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final c in sugeridos)
            ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 16),
              label: Text(c.nombre),
              onPressed: () => _usarConcepto(c.nombre),
            ),
        ],
      ),
    ];
  }

  /// Atajos con los conceptos que ya usaste (los más frecuentes primero).
  List<Widget> _seccionConceptos(BuildContext context, List<Gasto> gastos) {
    final conceptos = _conceptos(gastos);
    if (conceptos.isEmpty) return const [];
    final visibles = conceptos.take(_conceptosVisibles).toList();
    return [
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text('Tus conceptos',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          if (conceptos.length > _conceptosVisibles)
            TextButton(
              onPressed: () => _verTodosLosConceptos(conceptos),
              child: Text('Ver todos (${conceptos.length})'),
            ),
        ],
      ),
      Text('Elige uno y solo escribe el monto', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final c in visibles)
            ActionChip(
              label: Text(c.nombre),
              onPressed: () => _usarConcepto(c.nombre),
            ),
        ],
      ),
    ];
  }
}

/// Hoja con todos los conceptos, con buscador.
class _ConceptosSheet extends StatefulWidget {
  final List<ConceptoGasto> conceptos;

  const _ConceptosSheet({required this.conceptos});

  @override
  State<_ConceptosSheet> createState() => _ConceptosSheetState();
}

class _ConceptosSheetState extends State<_ConceptosSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final clave = claveConcepto(_query);
    final lista = [
      for (final c in widget.conceptos)
        if (clave.isEmpty || claveConcepto(c.nombre).contains(clave)) c,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tus conceptos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? const Center(child: Text('Nada coincide con tu búsqueda.'))
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(lista[i].nombre),
                        subtitle: Text(
                            '${lista[i].veces} ${lista[i].veces == 1 ? 'gasto' : 'gastos'} · última vez ${money(lista[i].ultimoMonto)}'),
                        onTap: () => Navigator.pop(context, lista[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickExpense extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  const _QuickExpense({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: outlined ? scheme.surface : scheme.primary.withValues(alpha: .10),
                border: outlined ? Border.all(color: scheme.primary, width: 1.4) : null,
              ),
              child: Icon(icon, color: scheme.primary),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
