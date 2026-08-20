/// Employee model representing an employee in the company
class Employee {
  final String id;
  final String name;
  final String position;
  final String departmentId;
  final String email;
  final String? phone;
  final String hireDate;
  final String? address;
  final List<String> skills;
  final List<Project> projects;

  Employee({
    required this.id,
    required this.name,
    required this.position,
    required this.departmentId,
    required this.email,
    this.phone,
    required this.hireDate,
    this.address,
    this.skills = const [],
    this.projects = const [],
  });

  /// Create an employee from JSON
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      departmentId: json['departmentId'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      hireDate: json['hireDate'] as String,
      address: json['address'] as String?,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((skill) => skill as String)
              .toList() ??
          [],
      projects: (json['projects'] as List<dynamic>?)
              ?.map((project) =>
                  Project.fromJson(project as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert employee to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'departmentId': departmentId,
      'email': email,
      'phone': phone,
      'hireDate': hireDate,
      'address': address,
      'skills': skills,
      'projects': projects.map((project) => project.toJson()).toList(),
    };
  }

  /// Create a copy of the employee with optional new values
  Employee copyWith({
    String? id,
    String? name,
    String? position,
    String? departmentId,
    String? email,
    String? phone,
    String? hireDate,
    String? address,
    List<String>? skills,
    List<Project>? projects,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      departmentId: departmentId ?? this.departmentId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      hireDate: hireDate ?? this.hireDate,
      address: address ?? this.address,
      skills: skills ?? this.skills,
      projects: projects ?? this.projects,
    );
  }

  @override
  String toString() => 'Employee(id: $id, name: $name, position: $position)';
}

/// Project model representing a project an employee is working on
class Project {
  final String id;
  final String name;
  final String role;

  Project({
    required this.id,
    required this.name,
    required this.role,
  });

  /// Create a project from JSON
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  /// Convert project to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
    };
  }

  /// Create a copy of the project with optional new values
  Project copyWith({
    String? id,
    String? name,
    String? role,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  @override
  String toString() => 'Project(id: $id, name: $name, role: $role)';
}
