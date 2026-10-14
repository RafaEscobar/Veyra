import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:veyra/core/errors/debug_error_log.dart';

final class DebugErrorLogsScreen extends StatelessWidget {
  const DebugErrorLogsScreen({super.key, this.log});

  final DebugErrorLog? log;

  @override
  Widget build(BuildContext context) {
    final DebugErrorLog errorLog = log ?? DebugErrorLog.instance;
    return AnimatedBuilder(
      animation: errorLog,
      builder: (context, _) {
        final entries = errorLog.entries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Logs de errores'),
            actions: <Widget>[
              IconButton(
                key: const ValueKey<String>('copy-error-logs'),
                tooltip: 'Copiar logs',
                onPressed: entries.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _asPlainText(entries)),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logs copiados.')),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                key: const ValueKey<String>('clear-error-logs'),
                tooltip: 'Limpiar logs',
                onPressed: entries.isEmpty ? null : errorLog.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se han registrado errores en esta ejecución.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final DebugErrorEntry entry = entries[index];
                    return ExpansionTile(
                      key: ValueKey<String>('error-log-$index'),
                      leading: const Icon(Icons.error_outline),
                      title: Text(entry.code),
                      subtitle: Text(
                        '${entry.errorType} · ${_formatDate(entry.occurredAt)}',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (entry.operation != null)
                          Text('Operación: ${entry.operation}'),
                        if (entry.causeType != null)
                          Text('Causa: ${entry.causeType}'),
                        if (entry.diagnosticCode != null)
                          Text('Detalle seguro: ${entry.diagnosticCode}'),
                        if (entry.stackFrames.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          const Text('Traza segura:'),
                          const SizedBox(height: 6),
                          SelectableText(entry.stackFrames.join('\n')),
                        ],
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  static String _asPlainText(Iterable<DebugErrorEntry> entries) {
    return entries
        .map((entry) {
          final String cause = entry.causeType == null
              ? ''
              : '\nCausa: ${entry.causeType}';
          final String operation = entry.operation == null
              ? ''
              : '\nOperación: ${entry.operation}';
          final String diagnostic = entry.diagnosticCode == null
              ? ''
              : '\nDetalle seguro: ${entry.diagnosticCode}';
          final String frames = entry.stackFrames.isEmpty
              ? ''
              : '\n${entry.stackFrames.join('\n')}';
          return '[${entry.occurredAt.toIso8601String()}] ${entry.code}\n'
              'Tipo: ${entry.errorType}$operation$cause$diagnostic$frames';
        })
        .join('\n\n');
  }

  static String _formatDate(DateTime date) {
    final DateTime local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
  }
}
