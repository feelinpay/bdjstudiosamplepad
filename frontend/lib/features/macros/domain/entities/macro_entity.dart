enum MacroActionType {
  changeWorkspace,
  changePage,
  setVolume,
  triggerPad,
  sendMidiNote,
  setLimiter,
  delay,
}

class MacroAction {
  final MacroActionType type;
  final Map<String, dynamic> params;

  const MacroAction({required this.type, required this.params});

  Map<String, dynamic> toJson() => {'type': type.name, 'params': params};

  factory MacroAction.fromJson(Map<String, dynamic> json) {
    return MacroAction(
      type: MacroActionType.values.byName(json['type']),
      params: Map<String, dynamic>.from(json['params']),
    );
  }
}

class MacroEntity {
  final int id;
  final String name;
  final List<MacroAction> actions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MacroEntity({
    required this.id,
    required this.name,
    required this.actions,
    required this.createdAt,
    this.updatedAt,
  });

  MacroEntity copyWith({
    int? id,
    String? name,
    List<MacroAction>? actions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MacroEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      actions: actions ?? this.actions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'actions': actions.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory MacroEntity.fromJson(Map<String, dynamic> json) {
    return MacroEntity(
      id: 0,
      name: json['name'] as String,
      actions: (json['actions'] as List)
          .map((a) => MacroAction.fromJson(a))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
