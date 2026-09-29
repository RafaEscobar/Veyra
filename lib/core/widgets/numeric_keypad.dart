import 'package:flutter/material.dart';

final class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<int> onDigitPressed;
  final VoidCallback onDeletePressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const List<int?> keys = <int?>[1, 2, 3, 4, 5, 6, 7, 8, 9, null, 0, -1];

    return SizedBox(
      width: 288,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
        ),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final int? value = keys[index];
          if (value == null) {
            return const SizedBox.shrink();
          }
          if (value == -1) {
            return IconButton(
              key: const ValueKey<String>('pin-delete'),
              tooltip: 'Borrar último dígito',
              onPressed: enabled ? onDeletePressed : null,
              icon: const Icon(Icons.backspace_outlined),
            );
          }
          return FilledButton.tonal(
            key: ValueKey<String>('pin-$value'),
            onPressed: enabled ? () => onDigitPressed(value) : null,
            child: Text('$value'),
          );
        },
      ),
    );
  }
}
