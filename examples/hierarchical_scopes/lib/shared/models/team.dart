/// Team model representing a team within a department
class Team {
  final String id;
  final String name;
  final String departmentId;
  final String description;
  final int memberCount;
  final List<String> members; // List of member names/IDs
  final String? leaderId; // Team lead

  Team({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.description,
    required this.memberCount,
    required this.members,
    this.leaderId,
  });

  /// Create a team from JSON
  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      departmentId: json['departmentId'] as String,
      description: json['description'] as String? ?? '',
      memberCount: json['memberCount'] as int? ?? 0,
      members: (json['members'] as List<dynamic>?)?.cast<String>() ?? [],
      leaderId: json['leaderId'] as String?,
    );
  }

  /// Convert team to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'departmentId': departmentId,
      'description': description,
      'memberCount': memberCount,
      'members': members,
      'leaderId': leaderId,
    };
  }

  /// Create a copy of the team with optional new values
  Team copyWith({
    String? id,
    String? name,
    String? departmentId,
    String? description,
    int? memberCount,
    List<String>? members,
    String? leaderId,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      departmentId: departmentId ?? this.departmentId,
      description: description ?? this.description,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
      leaderId: leaderId ?? this.leaderId,
    );
  }

  @override
  String toString() => 'Team(id: $id, name: $name, departmentId: $departmentId, memberCount: $memberCount)';
}