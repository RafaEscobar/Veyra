import 'package:flutter/material.dart';
import 'package:veyra/core/constants/app_constants.dart';

final class PinIndicator extends StatelessWidget {
  const PinIndicator({required this.filledCount, super.key});

  final int filledCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Semantics(
      label: 'NIP: $filledCount de ${AppConstants.pinLength} dígitos',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(AppConstants.pinLength, (int index) {
            final bool isFilled = index < filledCount;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? colors.primary : Colors.transparent,
                border: Border.all(color: colors.primary, width: 2),
              ),
            );
          }),
        ),
      ),
    );
  }
}
