/// Slim client object embedded inside a Task. NOT the full Client model
/// used by the admin client management screens.
class TaskClient {
  final int id;
  final String name;
  final String? status; // present on detail endpoint, absent on list

  const TaskClient({required this.id, required this.name, this.status});

  factory TaskClient.fromJson(Map<String, dynamic> json) {
    return TaskClient(
      id: json['id'] as int,
      name: (json['name'] ?? json['branch_name']) as String,
      status: json['status'] as String?,
    );
  }
}
