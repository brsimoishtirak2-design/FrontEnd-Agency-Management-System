/// Task status enum mirroring the backend's Task::STATUSES constant.
///
/// Backend: ['assigned', 'in_progress', 'submitted', 'changes_requested',
///           'approved', 'overdue', 'cancelled']
enum TaskStatus {
  assigned('assigned', 'Assigned'),
  inProgress('in_progress', 'In Progress'),
  submitted('submitted', 'Submitted'),
  changesRequested('changes_requested', 'Changes Requested'),
  approved('approved', 'Approved'),
  overdue('overdue', 'Overdue'),
  cancelled('cancelled', 'Cancelled');

  final String wireValue;
  final String displayName;
  const TaskStatus(this.wireValue, this.displayName);

  static TaskStatus fromWire(String value) {
    return TaskStatus.values.firstWhere(
      (s) => s.wireValue == value,
      orElse: () => TaskStatus.assigned,
    );
  }

  bool get isCompleted =>
      this == TaskStatus.approved || this == TaskStatus.cancelled;

  bool get isActionable => !isCompleted;
}
