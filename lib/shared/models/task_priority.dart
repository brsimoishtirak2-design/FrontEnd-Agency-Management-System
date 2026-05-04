/// Task priority enum mirroring the backend's Task::PRIORITIES constant.
///
/// Backend: ['low', 'medium', 'high', 'urgent']
enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  final String wireValue;
  final String displayName;
  const TaskPriority(this.wireValue, this.displayName);

  static TaskPriority fromWire(String value) {
    return TaskPriority.values.firstWhere(
      (p) => p.wireValue == value,
      orElse: () => TaskPriority.medium,
    );
  }

  /// Sort order — higher rank = more urgent. Useful for sorting task lists.
  int get rank {
    switch (this) {
      case TaskPriority.low:
        return 0;
      case TaskPriority.medium:
        return 1;
      case TaskPriority.high:
        return 2;
      case TaskPriority.urgent:
        return 3;
    }
  }
}
