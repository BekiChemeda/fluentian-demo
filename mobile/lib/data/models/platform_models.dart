class LanguageModel {
  const LanguageModel({
    required this.id,
    required this.isoCode,
    required this.englishName,
    required this.isActive,
    this.nativeName,
  });

  final String id;
  final String isoCode;
  final String englishName;
  final String? nativeName;
  final bool isActive;

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      id: json['id'].toString(),
      isoCode: json['iso_code'].toString(),
      englishName: json['english_name'].toString(),
      nativeName: json['native_name']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CourseModel {
  const CourseModel({
    required this.id,
    required this.code,
    required this.levelMin,
    required this.levelMax,
    required this.isPublished,
    this.title,
    this.description,
  });

  final String id;
  final String code;
  final String levelMin;
  final String levelMax;
  final String? title;
  final String? description;
  final bool isPublished;

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'].toString(),
      code: json['code'].toString(),
      levelMin: json['level_min'].toString(),
      levelMax: json['level_max'].toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      isPublished: json['is_published'] as bool? ?? false,
    );
  }
}

class LearningPathUnitModel {
  const LearningPathUnitModel({
    required this.id,
    required this.unitNo,
    required this.unitKind,
    required this.cefrLevel,
    required this.title,
    required this.lessonIds,
    this.description,
  });

  final String id;
  final int unitNo;
  final String unitKind;
  final String cefrLevel;
  final String title;
  final String? description;
  final List<int> lessonIds;

  factory LearningPathUnitModel.fromJson(Map<String, dynamic> json) {
    return LearningPathUnitModel(
      id: json['id'].toString(),
      unitNo: json['unit_no'] as int? ?? 0,
      unitKind: json['unit_kind']?.toString() ?? 'core',
      cefrLevel: json['cefr_level']?.toString() ?? 'a1',
      title: json['title']?.toString() ?? 'Unit',
      description: json['description']?.toString(),
      lessonIds: (json['lesson_ids'] as List<dynamic>? ?? const [])
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList(),
    );
  }
}

class LearningPathModel {
  const LearningPathModel({
    required this.courseCode,
    required this.currentLevel,
    required this.units,
    this.courseId,
    this.pathId,
  });

  final String? courseId;
  final String courseCode;
  final String? pathId;
  final String currentLevel;
  final List<LearningPathUnitModel> units;

  factory LearningPathModel.fromJson(Map<String, dynamic> json) {
    return LearningPathModel(
      courseId: json['course_id']?.toString(),
      courseCode: json['course_code']?.toString() ?? '',
      pathId: json['path_id']?.toString(),
      currentLevel: json['current_level']?.toString() ?? 'A1',
      units: (json['units'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LearningPathUnitModel.fromJson)
          .toList(),
    );
  }
}

class UsageItemModel {
  const UsageItemModel({
    required this.featureKey,
    required this.usedCount,
    this.limitCount,
  });

  final String featureKey;
  final int usedCount;
  final int? limitCount;

  factory UsageItemModel.fromJson(Map<String, dynamic> json) {
    return UsageItemModel(
      featureKey: json['feature_key'].toString(),
      usedCount: json['used_count'] as int? ?? 0,
      limitCount: json['limit_count'] as int?,
    );
  }
}

class SubscriptionModel {
  const SubscriptionModel({
    required this.tier,
    required this.status,
    required this.features,
  });

  final String tier;
  final String status;
  final Map<String, int?> features;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'] as Map<String, dynamic>? ?? const {};
    return SubscriptionModel(
      tier: json['tier']?.toString() ?? 'free',
      status: json['status']?.toString() ?? 'active',
      features: rawFeatures.map(
        (key, value) => MapEntry(key, value is int ? value : null),
      ),
    );
  }
}

class AiResultModel {
  const AiResultModel({
    required this.id,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String result;
  final DateTime createdAt;

  factory AiResultModel.fromJson(Map<String, dynamic> json) {
    return AiResultModel(
      id: json['id'].toString(),
      result: json['result']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TutorProfileModel {
  const TutorProfileModel({
    required this.id,
    required this.userId,
    required this.headline,
    required this.bio,
    required this.languages,
    required this.hourlyRate,
    required this.currency,
    required this.timezone,
  });

  final String id;
  final int userId;
  final String headline;
  final String bio;
  final String languages;
  final double hourlyRate;
  final String currency;
  final String timezone;

  factory TutorProfileModel.fromJson(Map<String, dynamic> json) {
    return TutorProfileModel(
      id: json['id'].toString(),
      userId: json['user_id'] as int? ?? 0,
      headline: json['headline']?.toString() ?? 'French tutor',
      bio: json['bio']?.toString() ?? '',
      languages: json['languages']?.toString() ?? 'French',
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      timezone: json['timezone']?.toString() ?? 'UTC',
    );
  }
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.tutorUserId,
    required this.studentUserId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.topic,
  });

  final String id;
  final int tutorUserId;
  final int studentUserId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String topic;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'].toString(),
      tutorUserId: json['tutor_user_id'] as int? ?? 0,
      studentUserId: json['student_user_id'] as int? ?? 0,
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'scheduled',
      topic: json['topic']?.toString() ?? '',
    );
  }
}

class OpportunityModel {
  const OpportunityModel({
    required this.id,
    required this.title,
    required this.providerName,
    required this.opportunityType,
    required this.description,
    required this.isPublished,
    this.countryCode,
    this.url,
    this.deadlineAt,
    this.eligibility,
  });

  final String id;
  final String title;
  final String providerName;
  final String opportunityType;
  final String? countryCode;
  final String? url;
  final String description;
  final String? eligibility;
  final DateTime? deadlineAt;
  final bool isPublished;

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? 'Opportunity',
      providerName: json['provider_name']?.toString() ?? '',
      opportunityType: json['opportunity_type']?.toString() ?? 'general',
      countryCode: json['country_code']?.toString(),
      url: json['url']?.toString(),
      description: json['description']?.toString() ?? '',
      eligibility: json['eligibility']?.toString(),
      deadlineAt: DateTime.tryParse(json['deadline_at']?.toString() ?? ''),
      isPublished: json['is_published'] as bool? ?? false,
    );
  }
}
