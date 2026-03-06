/// Data model for scope information from the running app
class ScopeData {
  final String id;
  final String name;
  final String? parentId;
  final String? parentName;
  final bool isDisposed;
  final bool isRoot;
  final List<String> controllers;
  final List<String> services;
  final List<String> others;
  final List<ScopeData> children;

  ScopeData({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
    required this.isDisposed,
    required this.isRoot,
    required this.controllers,
    required this.services,
    required this.others,
    required this.children,
  });

  int get dependencyCount =>
      controllers.length + services.length + others.length;

  factory ScopeData.fromJson(Map<String, dynamic> json) {
    return ScopeData(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      parentName: json['parentName'] as String?,
      isDisposed: json['isDisposed'] as bool? ?? false,
      isRoot: json['isRoot'] as bool? ?? false,
      controllers:
          (json['controllers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      services:
          (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      others:
          (json['others'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => ScopeData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'parentName': parentName,
      'isDisposed': isDisposed,
      'isRoot': isRoot,
      'controllers': controllers,
      'services': services,
      'others': others,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }
}
