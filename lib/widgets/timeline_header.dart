import 'package:flutter/material.dart';

/// Header level for timeline hierarchy
enum TimelineHeaderLevel {
  year,
  season,
  month,
}

/// Sticky header for timeline hierarchy (Year → Season → Month)
class TimelineHeader extends SliverPersistentHeaderDelegate {
  final String label;
  final double minHeight;
  final double maxHeight;
  final TimelineHeaderLevel level;

  TimelineHeader({
    required this.label,
    required this.level,
    this.minHeight = 48,
    this.maxHeight = 56,
  });

  /// Get text style based on header level
  TextStyle _getTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    
    switch (level) {
      case TimelineHeaderLevel.year:
        // Largest, most prominent - use displaySmall or headlineMedium
        return (textTheme.displaySmall ?? textTheme.headlineMedium ?? textTheme.titleLarge!).copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 28,
          letterSpacing: -0.5,
        );
      case TimelineHeaderLevel.season:
        // Medium size - use titleLarge
        return (textTheme.titleLarge ?? textTheme.titleMedium!).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: 0,
        );
      case TimelineHeaderLevel.month:
        // Smallest - use titleMedium
        return (textTheme.titleMedium ?? textTheme.bodyLarge!).copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          letterSpacing: 0.15,
        );
    }
  }

  /// Get horizontal padding (consistent for all levels)
  double _getHorizontalPadding() {
    return 16.0; // Consistent left padding for all headers
  }

  /// Get top divider color (subtle separator)
  Color? _getDividerColor(BuildContext context) {
    if (level == TimelineHeaderLevel.year) {
      return Theme.of(context).dividerColor.withOpacity(0.2);
    }
    return null;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = shrinkOffset / maxExtent;
    final opacity = 1.0 - (progress * 0.3).clamp(0.0, 0.3);
    final horizontalPadding = _getHorizontalPadding();
    final dividerColor = _getDividerColor(context);

    return Semantics(
      header: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(1.0),
          border: dividerColor != null
              ? Border(
                  top: BorderSide(
                    color: dividerColor,
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: level == TimelineHeaderLevel.year ? 16 : 12,
            ),
            child: Opacity(
              opacity: opacity,
              child: Text(
                label,
                style: _getTextStyle(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant TimelineHeader oldDelegate) {
    return oldDelegate.label != label || oldDelegate.level != level;
  }

  // Optional configuration methods - not all Flutter versions support these
  // They can be omitted if not available in the Flutter version being used

  @override
  TickerProvider get vsync {
    // This should never be called when used with SliverPersistentHeader
    throw UnimplementedError(
      'vsync is provided by SliverPersistentHeader widget',
    );
  }
}

/// Year header widget
class YearHeader extends StatelessWidget {
  final int year;

  const YearHeader({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: TimelineHeader(
        label: year.toString(),
        level: TimelineHeaderLevel.year,
        minHeight: 64,
        maxHeight: 72,
      ),
    );
  }
}

/// Season header widget
class SeasonHeader extends StatelessWidget {
  final String season;

  const SeasonHeader({super.key, required this.season});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: TimelineHeader(
        label: season,
        level: TimelineHeaderLevel.season,
        minHeight: 52,
        maxHeight: 56,
      ),
    );
  }
}

/// Month header widget
class MonthHeader extends StatelessWidget {
  final int month;
  final int year;

  const MonthHeader({
    super.key,
    required this.month,
    required this.year,
  });

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: false, // Month headers are not pinned - they scroll normally
      delegate: TimelineHeader(
        label: '${_getMonthName(month)} $year',
        level: TimelineHeaderLevel.month,
        minHeight: 44,
        maxHeight: 48,
      ),
    );
  }
}

