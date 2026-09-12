import 'package:flutter/material.dart';
import '../haptics.dart';
import '../theme.dart';

class FloatingPillDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingPillDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.charcoalBorder),
        boxShadow: AppTheme.dockShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(index: 0, label: 'Dashboard', icon: Icons.dashboard_rounded),
          const SizedBox(width: 28),
          _buildTabItem(index: 1, label: 'Positions', icon: Icons.business_center_outlined),
          const SizedBox(width: 28),
          _buildTabItem(index: 2, label: 'Logs', icon: Icons.format_list_bulleted_rounded),
          const SizedBox(width: 28),
          _buildTabItem(index: 3, label: 'Account', icon: Icons.person_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selectedIndex == index;

    return InkWell(
      onTap: () {
        AppHaptics.lightClick();
        onTabSelected(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? AppTheme.textWhite : AppTheme.textDim,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.textWhite : AppTheme.textDim,
            ),
          ),
        ],
      ),
    );
  }
}
