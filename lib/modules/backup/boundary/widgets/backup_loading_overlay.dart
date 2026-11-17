import 'package:flutter/material.dart';

/// Capa de carga que cubre la pantalla y bloquea los toques mientras una operación
/// de copias de seguridad está en curso (crear, restaurar, eliminar...).
class BackupLoadingOverlay extends StatelessWidget {
  const BackupLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.black38),
          Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(strokeWidth: 4),
                    ),
                    const SizedBox(height: 18),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Por favor espera, no cierres la app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
