/// Per-client commitment within a monthly plan: how many posts and videos
/// for client X in month Y.
///
/// Backend response (eager-loaded inside MonthlyPlan.planClients):
/// {
///   "id": int,
///   "monthly_plan_id": int,
///   "client_id": int,
///   "posts_count": int,
///   "videos_count": int,
///   "client": { "id": int, "name": string, "logo": string|null } | null,
/// }
class MonthlyPlanClient {
  final int id;
  final int monthlyPlanId;
  final int clientId;
  final int postsCount;
  final int videosCount;
  final String? clientName;
  final String? clientLogo;

  const MonthlyPlanClient({
    required this.id,
    required this.monthlyPlanId,
    required this.clientId,
    required this.postsCount,
    required this.videosCount,
    this.clientName,
    this.clientLogo,
  });

  factory MonthlyPlanClient.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    return MonthlyPlanClient(
      id: json['id'] as int,
      monthlyPlanId: json['monthly_plan_id'] as int,
      clientId: json['client_id'] as int,
      postsCount: json['posts_count'] as int? ?? 0,
      videosCount: json['videos_count'] as int? ?? 0,
      clientName: client?['name'] as String?,
      clientLogo: client?['logo'] as String?,
    );
  }

  int get totalCount => postsCount + videosCount;
}
