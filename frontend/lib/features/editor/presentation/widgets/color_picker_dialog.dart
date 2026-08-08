import 'package:flutter/material.dart';

class PadColorPicker extends StatelessWidget {
  final int currentColor;
  final ValueChanged<int> onColorSelected;

  const PadColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  static const List<int> _presetColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFF44336, // Red
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFFFEB3B, // Yellow
    0xFF00BCD4, // Cyan
    0xFFE91E63, // Pink
    0xFF8BC34A, // Light Green
    0xFF673AB7, // Deep Purple
    0xFF03A9F4, // Light Blue
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFF9E9E9E, // Grey
    0xFF000000, // Black
    0xFFFFFFFF, // White
    0xFF1A1A2E, // Dark Navy
    0xFF16213E, // Navy
    0xFF0F3460, // Royal Blue
    0xFF533483, // Indigo
    0xFFE94560, // Crimson
    0xFF2B2D42, // Charcoal
    0xFF8D99AE, // Slate
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Color del Pad',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current color preview
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color(currentColor),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white38, width: 2),
              ),
            ),
            const SizedBox(height: 16),
            // Preset colors grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _presetColors.length,
              itemBuilder: (context, index) {
                var color = _presetColors[index];
                var isSelected = color == currentColor;
                return GestureDetector(
                  onTap: () => onColorSelected(color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(color),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: isSelected ? 3 : 0,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
