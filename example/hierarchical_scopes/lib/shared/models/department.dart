import 'team.dart';

class Department {
  final String id;
  final String name;
  final String description;
  final int employeeCount;
  final double budget;
  final List<Team> teams;

  Department({
    required this.id,
    required this.name,
    required this.description,
    required this.employeeCount,
    required this.budget,
    required this.teams,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Department',
      description: json['description']?.toString() ?? '',
      employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      teams: (json['teams'] as List<dynamic>?)
          ?.map((teamData) {
        if (teamData is String) {
          // If it's just a string, create a basic Team object
          return Team(
            id: '${json['id']}_${teamData.toLowerCase().replaceAll(' ', '_')}',
            name: teamData,
            departmentId: json['id']?.toString() ?? '',
            description: 'Team $teamData in ${json['name']}',
            memberCount: 5, // Default member count
            members: [], // Will be populated by TeamService
          );
        } else if (teamData is Map<String, dynamic>) {
          // If it's a full team object, ensure it has departmentId
          return Team.fromJson({
            ...teamData,
            'departmentId': teamData['departmentId'] ?? json['id']?.toString() ?? '',
          });
        }
        throw Exception('Invalid team data: $teamData');
      })
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'employeeCount': employeeCount,
      'budget': budget,
      'teams': teams.map((team) => team.toJson()).toList(),
    };
  }
}