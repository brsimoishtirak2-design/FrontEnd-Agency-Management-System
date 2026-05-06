import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/planner_slot.dart';
import 'slot_chip.dart';

/// Landscape calendar grid for one month.
///
/// Columns: Sat, Sun, Mon, Tue, Wed, Thu, Fri (Friday rendered grayed-out
/// since it's the agency day off). Each cell shows the date number plus a
/// stack of [SlotChip]s for that day.
///
/// Slots are draggable when [onSlotMoved] is provided — long-press a chip
/// to lift it, drop on any non-Friday cell within the month to reschedule.
class MonthCalendarGrid extends StatelessWidget {
  final int year;
  final int month;
  final List<PlannerSlot> slots;
  final void Function(PlannerSlot slot)? onSlotTap;
  final void Function(DateTime date)? onEmptyDayTap;
  final void Function(PlannerSlot slot, DateTime newDate)? onSlotMoved;
  final void Function(DateTime date, List<PlannerSlot> slots)? onOverflowTap;
  final int? highlightUserId;

  const MonthCalendarGrid({
    super.key,
    required this.year,
    required this.month,
    required this.slots,
    this.onSlotTap,
    this.onEmptyDayTap,
    this.onSlotMoved,
    this.onOverflowTap,
    this.highlightUserId,
  });

  static const double _minCellWidth = 130;
  static const double _minCellHeight = 132;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstOfMonth = DateTime(year, month, 1);

    final slotsByDate = <int, List<PlannerSlot>>{};
    for (final s in slots) {
      if (s.slotDate.year == year && s.slotDate.month == month) {
        slotsByDate.putIfAbsent(s.slotDate.day, () => []).add(s);
      }
    }

    final dartWd = firstOfMonth.weekday;
    final saturdayFirstIdx = _toSaturdayFirst(dartWd);

    final cells = <_DayCell>[];
    for (var i = 0; i < saturdayFirstIdx; i++) {
      cells.add(const _DayCell.blank());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final isFriday = date.weekday == DateTime.friday;
      cells.add(_DayCell(
        date: date,
        slots: slotsByDate[d] ?? const [],
        isFriday: isFriday,
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(const _DayCell.blank());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final naturalWidth = _minCellWidth * 7;
        final useWidth =
            constraints.maxWidth > naturalWidth ? constraints.maxWidth : naturalWidth;
        final cellWidth = useWidth / 7;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: useWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeekdayHeader(cellWidth: cellWidth),
                const Divider(height: 1, thickness: 1, color: AppTheme.slate200),
                _GridBody(
                  cells: cells,
                  cellWidth: cellWidth,
                  cellHeight: _minCellHeight,
                  onSlotTap: onSlotTap,
                  onEmptyDayTap: onEmptyDayTap,
                  onSlotMoved: onSlotMoved,
                  onOverflowTap: onOverflowTap,
                  highlightUserId: highlightUserId,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _toSaturdayFirst(int dartWd) {
    switch (dartWd) {
      case DateTime.saturday:
        return 0;
      case DateTime.sunday:
        return 1;
      case DateTime.monday:
        return 2;
      case DateTime.tuesday:
        return 3;
      case DateTime.wednesday:
        return 4;
      case DateTime.thursday:
        return 5;
      case DateTime.friday:
        return 6;
    }
    return 0;
  }
}

class _WeekdayHeader extends StatelessWidget {
  final double cellWidth;
  const _WeekdayHeader({required this.cellWidth});

  static const _labels = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels.map((label) {
        final isFri = label == 'Fri';
        return SizedBox(
          width: cellWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFri ? AppTheme.slate300 : AppTheme.slate700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GridBody extends StatelessWidget {
  final List<_DayCell> cells;
  final double cellWidth;
  final double cellHeight;
  final void Function(PlannerSlot slot)? onSlotTap;
  final void Function(DateTime date)? onEmptyDayTap;
  final void Function(PlannerSlot slot, DateTime newDate)? onSlotMoved;
  final void Function(DateTime date, List<PlannerSlot> slots)? onOverflowTap;
  final int? highlightUserId;

  const _GridBody({
    required this.cells,
    required this.cellWidth,
    required this.cellHeight,
    required this.onSlotTap,
    required this.onEmptyDayTap,
    required this.onSlotMoved,
    required this.onOverflowTap,
    required this.highlightUserId,
  });

  @override
  Widget build(BuildContext context) {
    final rowCount = cells.length ~/ 7;
    return Column(
      children: List.generate(rowCount, (rowIdx) {
        return Row(
          children: List.generate(7, (col) {
            final cell = cells[rowIdx * 7 + col];
            return SizedBox(
              width: cellWidth,
              height: cellHeight,
              child: _DayCellWidget(
                cell: cell,
                onSlotTap: onSlotTap,
                onEmptyDayTap: onEmptyDayTap,
                onSlotMoved: onSlotMoved,
                onOverflowTap: onOverflowTap,
                highlightUserId: highlightUserId,
              ),
            );
          }),
        );
      }),
    );
  }
}

class _DayCell {
  final DateTime? date;
  final List<PlannerSlot> slots;
  final bool isFriday;

  const _DayCell({
    required this.date,
    required this.slots,
    required this.isFriday,
  });

  const _DayCell.blank()
      : date = null,
        slots = const [],
        isFriday = false;

  bool get isBlank => date == null;
}

class _DayCellWidget extends StatelessWidget {
  final _DayCell cell;
  final void Function(PlannerSlot slot)? onSlotTap;
  final void Function(DateTime date)? onEmptyDayTap;
  final void Function(PlannerSlot slot, DateTime newDate)? onSlotMoved;
  final void Function(DateTime date, List<PlannerSlot> slots)? onOverflowTap;
  final int? highlightUserId;

  const _DayCellWidget({
    required this.cell,
    required this.onSlotTap,
    required this.onEmptyDayTap,
    required this.onSlotMoved,
    required this.onOverflowTap,
    required this.highlightUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (cell.isBlank) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: AppTheme.slate100, width: 1),
            bottom: BorderSide(color: AppTheme.slate100, width: 1),
          ),
          color: AppTheme.slate50,
        ),
      );
    }

    final date = cell.date!;
    final canDrop = !cell.isFriday && onSlotMoved != null;

    final Widget interior = _CellInterior(
      cell: cell,
      onSlotTap: onSlotTap,
      onSlotMoved: onSlotMoved,
      onOverflowTap: onOverflowTap,
      highlightUserId: highlightUserId,
    );

    Widget framed;
    if (canDrop) {
      framed = DragTarget<PlannerSlot>(
        onWillAcceptWithDetails: (details) {
          // Don't accept dropping a slot back onto its own date
          return details.data.slotDate.day != date.day ||
              details.data.slotDate.month != date.month ||
              details.data.slotDate.year != date.year;
        },
        onAcceptWithDetails: (details) {
          onSlotMoved?.call(details.data, date);
        },
        builder: (context, candidates, rejected) {
          final isHovering = candidates.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              color: isHovering
                  ? AppTheme.brandPrimary.withValues(alpha: 0.08)
                  : Colors.white,
              border: Border(
                right: const BorderSide(color: AppTheme.slate100, width: 1),
                bottom: const BorderSide(color: AppTheme.slate100, width: 1),
                top: isHovering
                    ? const BorderSide(color: AppTheme.brandPrimary, width: 2)
                    : BorderSide.none,
                left: isHovering
                    ? const BorderSide(color: AppTheme.brandPrimary, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: interior,
          );
        },
      );
    } else {
      framed = Container(
        decoration: BoxDecoration(
          color: cell.isFriday ? AppTheme.slate50 : Colors.white,
          border: const Border(
            right: BorderSide(color: AppTheme.slate100, width: 1),
            bottom: BorderSide(color: AppTheme.slate100, width: 1),
          ),
        ),
        child: interior,
      );
    }

    if (cell.isFriday) {
      return framed;
    }
    return InkWell(
      onTap: () => onEmptyDayTap?.call(date),
      child: framed,
    );
  }
}

class _CellInterior extends StatelessWidget {
  final _DayCell cell;
  final void Function(PlannerSlot slot)? onSlotTap;
  final void Function(PlannerSlot slot, DateTime newDate)? onSlotMoved;
  final void Function(DateTime date, List<PlannerSlot> slots)? onOverflowTap;
  final int? highlightUserId;

  const _CellInterior({
    required this.cell,
    required this.onSlotTap,
    required this.onSlotMoved,
    required this.onOverflowTap,
    required this.highlightUserId,
  });

  @override
  Widget build(BuildContext context) {
    final date = cell.date!;
    final isToday = _isToday(date);
    final canDrag = onSlotMoved != null;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: isToday ? AppTheme.brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? Colors.white
                        : (cell.isFriday
                            ? AppTheme.slate300
                            : AppTheme.slate700),
                  ),
                ),
              ),
              if (cell.slots.isNotEmpty)
                Text(
                  '${cell.slots.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: cell.isFriday
                ? Center(
                    child: Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate300,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                : _buildSlotsList(cell.slots, canDrag),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Lightweight slot stack — no ListView (avoids spinning up a viewport per
  /// cell). At most 4 chips render; the rest collapse into a "+N more" tag.
  Widget _buildSlotsList(List<PlannerSlot> slots, bool canDrag) {
    if (slots.isEmpty) return const SizedBox.shrink();
    const maxVisible = 4;
    final visible = slots.length <= maxVisible
        ? slots
        : slots.take(maxVisible - 1).toList();
    final overflow = slots.length - visible.length;

    final children = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 2));
      children.add(_buildChip(visible[i], canDrag));
    }
    if (overflow > 0) {
      children.add(const SizedBox(height: 2));
      children.add(_overflowBadge(overflow, slots));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildChip(PlannerSlot s, bool canDrag) {
    final isMine =
        highlightUserId != null && s.assignedUserId == highlightUserId;
    final chip = SlotChip(
      slot: s,
      dense: true,
      onTap: () => onSlotTap?.call(s),
    );
    final wrapped = isMine
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppTheme.brandPrimary, width: 1.5),
            ),
            padding: const EdgeInsets.all(1),
            child: chip,
          )
        : chip;

    if (!canDrag) return wrapped;
    return LongPressDraggable<PlannerSlot>(
      data: s,
      delay: const Duration(milliseconds: 250),
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SlotChip(slot: s, dense: false),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: wrapped),
      child: wrapped,
    );
  }

  Widget _overflowBadge(int count, List<PlannerSlot> allSlots) {
    final tap = onOverflowTap;
    final date = cell.date;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (tap == null || date == null)
            ? null
            : () => tap(date, allSlots),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.slate100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '+$count more',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate700,
            ),
          ),
        ),
      ),
    );
  }
}
