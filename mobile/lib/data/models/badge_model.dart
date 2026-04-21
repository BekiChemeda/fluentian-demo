class BadgeModel {
  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.unlockDate,
    required this.unlockCriteria,
    required this.iconSvg,
  });

  final int id;
  final String name;
  final String description;
  final bool unlocked;
  final String? unlockDate;
  final String unlockCriteria;
  final String iconSvg;

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      unlocked: json['unlocked'] as bool,
      unlockDate: json['unlock_date'] as String?,
      unlockCriteria: json['unlock_criteria'] as String,
      iconSvg: (json['icon_svg'] as String?) ?? '',
    );
  }
}
