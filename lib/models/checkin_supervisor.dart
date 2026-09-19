class CheckinSupervisor {
  final int id;
  final String username;
  final String realName;
  final String? phone;
  final int status;
  final List<int> projectIds;

  const CheckinSupervisor({
    required this.id,
    required this.username,
    required this.realName,
    this.phone,
    required this.status,
    required this.projectIds,
  });

  factory CheckinSupervisor.fromJson(Map<String, dynamic> json) =>
      CheckinSupervisor(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        realName: json['realName'] as String? ?? '',
        phone: json['phone'] as String?,
        status: json['status'] as int? ?? 1,
        projectIds: (json['projectIds'] as List? ?? const [])
            .map((id) => (id as num).toInt())
            .toList(),
      );
}
