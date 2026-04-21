class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.xp,
    required this.streak,
    required this.dailyXpGoal,
  });

  final int id;
  final String email;
  final String nativeLanguage;
  final String targetLanguage;
  final int xp;
  final int streak;
  final int dailyXpGoal;

  UserModel copyWith({
    int? id,
    String? email,
    String? nativeLanguage,
    String? targetLanguage,
    int? xp,
    int? streak,
    int? dailyXpGoal,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      dailyXpGoal: dailyXpGoal ?? this.dailyXpGoal,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        email: json['email'] as String,
        nativeLanguage: json['native_language'] as String,
        targetLanguage: json['target_language'] as String,
        xp: json['xp'] as int,
        streak: json['streak'] as int,
        dailyXpGoal: json['daily_xp_goal'] as int,
      );
}
