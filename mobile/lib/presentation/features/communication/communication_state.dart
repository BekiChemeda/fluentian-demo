class CommunicationParticipant {
  const CommunicationParticipant({
    required this.id,
    required this.email,
    required this.xp,
    required this.streak,
    required this.language,
  });

  final int id;
  final String email;
  final int xp;
  final int streak;
  final String? language;

  factory CommunicationParticipant.fromJson(Map<String, dynamic> json) {
    return CommunicationParticipant(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? 'partner',
      xp: json['xp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      language:
          json['native_language'] as String? ?? json['language'] as String?,
    );
  }
}

class CommunicationSession {
  const CommunicationSession({
    required this.sessionId,
    required this.sessionType,
    required this.status,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.recordingUrl,
    this.reportFlag = false,
  });

  final int sessionId;
  final String sessionType;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String? recordingUrl;
  final bool reportFlag;

  factory CommunicationSession.fromMatchEvent(Map<String, dynamic> json) {
    return CommunicationSession(
      sessionId: json['session_id'] as int? ?? 0,
      sessionType: json['session_type'] as String? ?? 'text',
      status: 'active',
      startTime: DateTime.now().toUtc(),
      recordingUrl: json['recording_url'] as String?,
      reportFlag: false,
    );
  }

  CommunicationSession copyWith({
    String? status,
    DateTime? endTime,
    int? durationSeconds,
    String? recordingUrl,
    bool? reportFlag,
  }) {
    return CommunicationSession(
      sessionId: sessionId,
      sessionType: sessionType,
      status: status ?? this.status,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      reportFlag: reportFlag ?? this.reportFlag,
    );
  }
}

class CommunicationStats {
  const CommunicationStats({
    required this.today,
    required this.yesterday,
    required this.weekly,
    required this.totalSessions,
    required this.averageSessionDuration,
    required this.lastActiveTime,
  });

  final int today;
  final int yesterday;
  final int weekly;
  final int totalSessions;
  final double averageSessionDuration;
  final DateTime? lastActiveTime;

  factory CommunicationStats.fromJson(Map<String, dynamic> json) {
    return CommunicationStats(
      today: json['today'] as int? ?? 0,
      yesterday: json['yesterday'] as int? ?? 0,
      weekly: json['weekly'] as int? ?? 0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      averageSessionDuration:
          (json['average_session_duration'] as num?)?.toDouble() ?? 0,
      lastActiveTime: json['last_active_time'] == null
          ? null
          : DateTime.tryParse(json['last_active_time'] as String),
    );
  }
}

enum CommunicationConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed
}

enum CommunicationQueueStatus { idle, queued, searching, matched, leaving }

enum CommunicationPhase { match, session, postSession }

class CommunicationMessage {
  const CommunicationMessage({
    required this.author,
    required this.body,
    required this.createdAt,
    this.isMe = false,
  });

  final String author;
  final String body;
  final DateTime createdAt;
  final bool isMe;
}

class CommunicationState {
  const CommunicationState({
    this.connectionStatus = CommunicationConnectionStatus.disconnected,
    this.queueStatus = CommunicationQueueStatus.idle,
    this.phase = CommunicationPhase.match,
    this.presenceLabel = 'OFFLINE',
    this.partner,
    this.session,
    this.stats,
    this.messages = const [],
    this.waitingPhrase = 'Recherche d\'un partenaire...',
    this.errorMessage,
    this.selectedMode = 'text',
    this.selectedIntent = 'casual',
    this.selectedLevel = 'A1',
    this.recordingConsent = false,
    this.isMuted = false,
    this.callSignalStatus = 'idle',
    this.sttAvailable = false,
    this.ttsAvailable = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.liveTranscript = '',
  });

  final CommunicationConnectionStatus connectionStatus;
  final CommunicationQueueStatus queueStatus;
  final CommunicationPhase phase;
  final String presenceLabel;
  final CommunicationParticipant? partner;
  final CommunicationSession? session;
  final CommunicationStats? stats;
  final List<CommunicationMessage> messages;
  final String waitingPhrase;
  final String? errorMessage;
  final String selectedMode;
  final String selectedIntent;
  final String selectedLevel;
  final bool recordingConsent;
  final bool isMuted;
  final String callSignalStatus;
  final bool sttAvailable;
  final bool ttsAvailable;
  final bool isListening;
  final bool isSpeaking;
  final String liveTranscript;

  bool get isBusy =>
      queueStatus == CommunicationQueueStatus.queued ||
      queueStatus == CommunicationQueueStatus.searching;

  CommunicationState copyWith({
    CommunicationConnectionStatus? connectionStatus,
    CommunicationQueueStatus? queueStatus,
    CommunicationPhase? phase,
    String? presenceLabel,
    CommunicationParticipant? partner,
    CommunicationSession? session,
    CommunicationStats? stats,
    List<CommunicationMessage>? messages,
    String? waitingPhrase,
    String? errorMessage,
    String? selectedMode,
    String? selectedIntent,
    String? selectedLevel,
    bool? recordingConsent,
    bool? isMuted,
    String? callSignalStatus,
    bool? sttAvailable,
    bool? ttsAvailable,
    bool? isListening,
    bool? isSpeaking,
    String? liveTranscript,
  }) {
    return CommunicationState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      queueStatus: queueStatus ?? this.queueStatus,
      phase: phase ?? this.phase,
      presenceLabel: presenceLabel ?? this.presenceLabel,
      partner: partner ?? this.partner,
      session: session ?? this.session,
      stats: stats ?? this.stats,
      messages: messages ?? this.messages,
      waitingPhrase: waitingPhrase ?? this.waitingPhrase,
      errorMessage: errorMessage,
      selectedMode: selectedMode ?? this.selectedMode,
      selectedIntent: selectedIntent ?? this.selectedIntent,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      recordingConsent: recordingConsent ?? this.recordingConsent,
      isMuted: isMuted ?? this.isMuted,
      callSignalStatus: callSignalStatus ?? this.callSignalStatus,
      sttAvailable: sttAvailable ?? this.sttAvailable,
      ttsAvailable: ttsAvailable ?? this.ttsAvailable,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      liveTranscript: liveTranscript ?? this.liveTranscript,
    );
  }
}
