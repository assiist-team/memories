import 'package:flutter/material.dart';

/// Year sidebar widget for timeline navigation
/// 
/// Displays a scrollable list of years on the left side of the timeline.
/// Highlights the active year based on scroll position and allows tapping
/// to navigate to that year's content.
class YearSidebar extends StatelessWidget {
  final List<int> years;
  final int? activeYear;
  final ValueChanged<int> onYearTap;

  const YearSidebar({
    super.key,
    required this.years,
    this.activeYear,
    required this.onYearTap,
  });

  @override
  Widget build(BuildContext context) {
    if (years.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scaffoldBackground = theme.scaffoldBackgroundColor;

    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: scaffoldBackground,
        border: Border(
          right: BorderSide(
            color: Colors.white,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];
          final isActive = year == activeYear;
          
          return _YearSidebarItem(
            key: ValueKey('year_${year}_active_$isActive'),
            year: year,
            isActive: isActive,
            onTap: () => onYearTap(year),
            theme: theme,
            colorScheme: colorScheme,
          );
        },
      ),
    );
  }
}

class _YearSidebarItem extends StatelessWidget {
  final int year;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _YearSidebarItem({
    super.key,
    required this.year,
    required this.isActive,
    required this.onTap,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Navigate to year $year',
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: 0,
              child: Text(
                year.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? const Color(0xFF2B2B2B)
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

