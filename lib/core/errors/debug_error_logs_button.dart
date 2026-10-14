import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:veyra/core/errors/debug_error_logs_screen.dart';

final class DebugErrorLogsButton extends StatelessWidget {
  const DebugErrorLogsButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey<String>('debug-error-logs'),
      tooltip: 'Ver logs de errores',
      onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const DebugErrorLogsScreen(),
        ),
      ),
      icon: const Icon(Icons.bug_report_outlined),
    );
  }
}
