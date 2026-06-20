import 'package:flutter/material.dart';

/// A single key on the [NepaliKeyboard]. Renders either a [label] (a Devanagari
/// character) or an [icon] (for action keys like backspace). Designed to sit
/// inside an [Expanded] in a key row, so width adapts to the screen.
class NepaliKeyButton extends StatelessWidget {
  const NepaliKeyButton({
    super.key,
    required this.onTap,
    this.label,
    this.icon,
    this.accent = false,
  }) : assert(label != null || icon != null, 'label or icon required');

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;

  /// Accent keys (space, backspace, mode switches) use the primary container
  /// colour to stand apart from character keys.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = accent ? cs.primaryContainer : cs.surface;
    final Color fg = accent ? cs.onPrimaryContainer : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: icon != null
                ? Icon(icon, size: 18, color: fg)
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label!,
                      style: TextStyle(fontSize: 19, color: fg),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
