import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/realtime/webrtc_call_service.dart';
import '../../../data/repositories/communication_repository.dart';
import 'communication_state.dart';
import '../../app/providers.dart';

final communicationControllerProvider =
    NotifierProvider<CommunicationController, CommunicationState>(
  CommunicationController.new,
);

class CommunicationController extends Notifier<CommunicationState> {
  static const _waitingPhrases = <String>[
    'Recherche d\'un partenaire...',
    'On ajuste le niveau et l\'objectif...',
    'Connexion en cours avec un apprenant...',
    'Encore un instant pour trouver le bon match.',
  ];

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  Timer? _phraseTimer;
  Timer? _heartbeatTimer;
  int _phraseIndex = 0;
  int _reconnectAttempts = 0;
  bool _reconnectScheduled = false;
  final WebRtcCallService _webRtc = WebRtcCallService();
  final Set<int> _seenMessageIds = <int>{};
  final Queue<int> _seenMessageOrder = ListQueue<int>();

  @override
  CommunicationState build() {
    ref.onDispose(() {
      _socketSubscription?.cancel();
      _channel?.sink.close();
      _phraseTimer?.cancel();
      _heartbeatTimer?.cancel();
      unawaited(_webRtc.dispose());
    });
    return const CommunicationState();
  }

  CommunicationRepository get _repository =>
      ref.read(communicationRepositoryProvider);

  Future<void> bootstrap() async {
    await _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _repository.getUserStats();
      final stats = CommunicationStats.fromJson(data);
      state = state.copyWith(stats: stats);
    } catch (_) {}
  }

  Future<void> joinQueue() async {
    if (state.isBusy) {
      return;
    }

    state = state.copyWith(
      connectionStatus: CommunicationConnectionStatus.connecting,
      queueStatus: CommunicationQueueStatus.queued,
      phase: CommunicationPhase.match,
      presenceLabel: 'IN_QUEUE',
      errorMessage: null,
    );

    try {
      await _connectSocketIfNeeded();
      await _repository.joinQueue(
        preferredMode: state.selectedMode,
        learningIntent: state.selectedIntent,
        cefrLevel: state.selectedLevel,
        recordingConsent: state.recordingConsent,
      );
      _startPhraseRotation();
      _startHeartbeat();
      state = state.copyWith(
        connectionStatus: CommunicationConnectionStatus.connected,
        queueStatus: CommunicationQueueStatus.searching,
        presenceLabel: 'IN_QUEUE',
        waitingPhrase: _waitingPhrases.first,
      );
    } catch (error) {
      state = state.copyWith(
        connectionStatus: CommunicationConnectionStatus.failed,
        queueStatus: CommunicationQueueStatus.idle,
        errorMessage: error.toString(),
        presenceLabel: 'OFFLINE',
      );
    }
  }

  Future<void> leaveQueue() async {
    _phraseTimer?.cancel();
    _stopHeartbeat();
    await _webRtc.dispose();
    state = state.copyWith(
      queueStatus: CommunicationQueueStatus.leaving,
      presenceLabel: 'ONLINE',
    );
    try {
      await _repository.leaveQueue();
    } catch (_) {}
    await _closeSocket();
    state = state.copyWith(
      connectionStatus: CommunicationConnectionStatus.disconnected,
      queueStatus: CommunicationQueueStatus.idle,
      phase: CommunicationPhase.match,
      presenceLabel: 'ONLINE',
      partner: null,
      session: null,
      messages: const [],
      waitingPhrase: _waitingPhrases.first,
    );
    _seenMessageIds.clear();
    _seenMessageOrder.clear();
  }

  Future<void> sendTextMessage(String body) async {
    final partner = state.partner;
    final text = body.trim();
    if (partner == null || text.isEmpty) {
      return;
    }

    // Prefer the websocket path for active sessions to keep text/audio chat on one realtime channel.
    if (_channel != null && state.phase == CommunicationPhase.session) {
      _sendSocketEvent(type: 'CHAT_MESSAGE', payload: {'body': text});
      return;
    }

    final sent =
        await _repository.sendTextMessage(receiverId: partner.id, body: text);
    final messageId = sent['id'] as int?;
    if (messageId != null && !_rememberMessageId(messageId)) {
      return;
    }
    final createdAt = DateTime.tryParse(sent['created_at'] as String? ?? '') ??
        DateTime.now().toUtc();
    state = state.copyWith(
      messages: [
        ...state.messages,
        CommunicationMessage(
          author: 'You',
          body: sent['body'] as String? ?? text,
          createdAt: createdAt,
          isMe: true,
        ),
      ],
    );
  }

  Future<void> refreshMessages() async {
    final partner = state.partner;
    if (partner == null) {
      return;
    }

    try {
      final items = await _repository.listMessages(partner.id);
      final parsed = items.map((item) {
        final id = item['id'] as int?;
        if (id != null) {
          _rememberMessageId(id);
        }
        return CommunicationMessage(
          author: (item['sender_id'] as int? ?? 0) == partner.id
              ? partner.email
              : 'You',
          body: item['body'] as String? ?? '',
          createdAt: DateTime.tryParse(item['created_at'] as String? ?? '') ??
              DateTime.now().toUtc(),
          isMe: (item['sender_id'] as int? ?? 0) != partner.id,
        );
      }).toList();
      state = state.copyWith(messages: parsed);
    } catch (_) {}
  }

  Future<void> endSession({required int endedBy}) async {
    final session = state.session;
    if (session == null) {
      return;
    }

    final duration =
        DateTime.now().toUtc().difference(session.startTime).inSeconds;
    try {
      final data = await _repository.endSession(
        sessionId: session.sessionId,
        duration: duration,
        endedBy: endedBy,
      );
      final endedSession = CommunicationSession(
        sessionId: data['session_id'] as int? ?? session.sessionId,
        sessionType: data['session_type'] as String? ?? session.sessionType,
        status: data['status'] as String? ?? 'ended',
        startTime: session.startTime,
        endTime: DateTime.tryParse(data['end_time'] as String? ?? '') ??
            DateTime.now().toUtc(),
        durationSeconds: data['duration'] as int? ?? duration,
        recordingUrl: data['recording_url'] as String?,
        reportFlag: data['report_flag'] as bool? ?? false,
      );
      state = state.copyWith(
        session: endedSession,
        phase: CommunicationPhase.postSession,
        queueStatus: CommunicationQueueStatus.idle,
        presenceLabel: 'ONLINE',
      );
      await _loadStats();
      await _closeSocket();
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> inviteCall() async {
    try {
      await _ensureWebRtcReady();
      final offer = await _webRtc.createOffer();
      _sendSocketEvent(type: 'CALL_INVITE', payload: {'mode': 'audio'});
      _sendSocketEvent(type: 'WEBRTC_OFFER', payload: offer);
      state = state.copyWith(callSignalStatus: 'offer_sent');
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString(), callSignalStatus: 'offer_failed');
    }
  }

  Future<void> toggleMute() async {
    final next = !state.isMuted;
    await _webRtc.setMuted(next);
    state = state.copyWith(isMuted: next);
    _sendSocketEvent(type: 'CALL_MUTE_TOGGLED', payload: {'muted': next});
  }

  Future<void> hangupCall() async {
    _sendSocketEvent(type: 'CALL_HANGUP', payload: {'reason': 'user_end'});
    await _webRtc.resetPeer();
    state = state.copyWith(callSignalStatus: 'ended');
  }

  Future<void> reportCurrentPartner(String reason) async {
    final session = state.session;
    final partner = state.partner;
    if (session == null || partner == null) {
      return;
    }
    await _repository.reportUser(
      sessionId: session.sessionId,
      reportedUserId: partner.id,
      reason: reason,
    );
    state = state.copyWith(
      session: session.copyWith(reportFlag: true),
    );
  }

  Future<void> blockCurrentPartner(String reason) async {
    final partner = state.partner;
    if (partner == null) {
      return;
    }
    await _repository.blockUser(targetUserId: partner.id, reason: reason);
    state = state.copyWith(errorMessage: 'User blocked');
  }

  Future<void> updateSelectedMode(String value) async {
    state = state.copyWith(selectedMode: value);
  }

  Future<void> updateSelectedIntent(String value) async {
    state = state.copyWith(selectedIntent: value);
  }

  Future<void> updateSelectedLevel(String value) async {
    state = state.copyWith(selectedLevel: value);
  }

  Future<void> updateRecordingConsent(bool value) async {
    state = state.copyWith(recordingConsent: value);
  }

  Future<void> _connectSocketIfNeeded() async {
    if (_channel != null) {
      return;
    }

    final channel = await _repository.connectSocket();
    _channel = channel;
    _socketSubscription = channel.stream.listen(
      _handleSocketEvent,
      onError: (Object error) {
        state = state.copyWith(
          connectionStatus: CommunicationConnectionStatus.failed,
          errorMessage: error.toString(),
        );
        _scheduleReconnect();
      },
      onDone: () {
        if (state.phase == CommunicationPhase.session) {
          state = state.copyWith(
            connectionStatus: CommunicationConnectionStatus.reconnecting,
          );
        } else {
          state = state.copyWith(
            connectionStatus: CommunicationConnectionStatus.disconnected,
          );
        }
        _scheduleReconnect();
      },
    );
    _reconnectAttempts = 0;
    _reconnectScheduled = false;

    if (state.queueStatus == CommunicationQueueStatus.searching ||
        state.phase == CommunicationPhase.session) {
      _startHeartbeat();
    }
  }

  void _handleSocketEvent(dynamic rawEvent) {
    final event = rawEvent is String
        ? jsonDecode(rawEvent) as Map<String, dynamic>
        : rawEvent as Map<String, dynamic>;
    final type = (event['type'] as String? ?? '').toUpperCase();
    final payload = event['payload'] as Map<String, dynamic>? ?? const {};

    switch (type) {
      case 'MATCH_PROGRESS':
        _startHeartbeat();
        state = state.copyWith(
          queueStatus: CommunicationQueueStatus.searching,
          waitingPhrase: payload['queue_joined'] == true
              ? _waitingPhrases[_phraseIndex]
              : state.waitingPhrase,
        );
        break;
      case 'MATCH_FOUND':
        _phraseTimer?.cancel();
        _startHeartbeat();
        final sessionType = payload['session_type'] as String? ?? 'text';
        state = state.copyWith(
          queueStatus: CommunicationQueueStatus.matched,
          phase: CommunicationPhase.session,
          presenceLabel: 'IN_SESSION',
          partner: CommunicationParticipant(
            id: payload['peer_id'] as int? ?? 0,
            email: payload['peer_email'] as String? ?? 'partner',
            xp: payload['peer_xp'] as int? ?? 0,
            streak: payload['peer_streak'] as int? ?? 0,
            language: payload['peer_language'] as String?,
          ),
          session: CommunicationSession.fromMatchEvent(payload),
          messages: const [],
          callSignalStatus: 'idle',
          isMuted: false,
        );
        if (sessionType == 'audio') {
          unawaited(_ensureWebRtcReady());
          unawaited(_autoStartAudioSignaling(payload));
        }
        if (sessionType == 'text') {
          refreshMessages();
        }
        break;
      case 'SESSION_INITIALIZED':
      case 'SESSION_STARTED':
      case 'SESSION_ACTIVE':
        state = state.copyWith(
          phase: CommunicationPhase.session,
          queueStatus: CommunicationQueueStatus.matched,
          presenceLabel: 'IN_SESSION',
        );
        break;
      case 'SESSION_ENDED':
        _stopHeartbeat();
        unawaited(_webRtc.dispose());
        final currentSession = state.session;
        if (currentSession != null) {
          state = state.copyWith(
            session: currentSession.copyWith(
              status: 'ended',
              durationSeconds:
                  payload['duration'] as int? ?? currentSession.durationSeconds,
            ),
            phase: CommunicationPhase.postSession,
            queueStatus: CommunicationQueueStatus.idle,
            presenceLabel: 'ONLINE',
            callSignalStatus: 'ended',
          );
          _seenMessageIds.clear();
          _seenMessageOrder.clear();
        }
        break;
      case 'CHAT_MESSAGE':
        final messageId = payload['id'] as int?;
        if (messageId != null && !_rememberMessageId(messageId)) {
          break;
        }
        final body = payload['body'] as String? ?? '';
        if (body.isEmpty) {
          break;
        }
        final senderId = payload['sender_id'] as int? ?? 0;
        final partner = state.partner;
        final isMe = partner == null ? false : senderId != partner.id;
        final author = isMe ? 'You' : (partner?.email ?? 'Partner');
        final createdAt =
            DateTime.tryParse(payload['created_at'] as String? ?? '') ??
                DateTime.now().toUtc();
        state = state.copyWith(
          messages: [
            ...state.messages,
            CommunicationMessage(
              author: author,
              body: body,
              createdAt: createdAt,
              isMe: isMe,
            ),
          ],
        );
        break;
      case 'WEBRTC_OFFER':
        state = state.copyWith(callSignalStatus: 'offer_received');
        unawaited(_handleWebRtcOffer(payload));
        break;
      case 'WEBRTC_ANSWER':
        state = state.copyWith(callSignalStatus: 'answer_received');
        unawaited(_handleWebRtcAnswer(payload));
        break;
      case 'WEBRTC_ICE_CANDIDATE':
        state = state.copyWith(callSignalStatus: 'ice_exchange');
        unawaited(_handleWebRtcIce(payload));
        break;
      case 'CALL_INVITE':
        state = state.copyWith(callSignalStatus: 'incoming_invite');
        break;
      case 'CALL_HANGUP':
        unawaited(_webRtc.resetPeer());
        state = state.copyWith(callSignalStatus: 'ended', isMuted: false);
        break;
      case 'CALL_MUTE_TOGGLED':
        state = state.copyWith(callSignalStatus: 'mute_updated');
        break;
      case 'USER_DISCONNECTED':
        _stopHeartbeat();
        state = state.copyWith(
          queueStatus: CommunicationQueueStatus.idle,
          phase: CommunicationPhase.match,
          presenceLabel: 'ONLINE',
          errorMessage: 'Partner disconnected',
        );
        _seenMessageIds.clear();
        _seenMessageOrder.clear();
        break;
      case 'ERROR_EVENT':
        state = state.copyWith(
            errorMessage:
                payload['reason'] as String? ?? 'communication_error');
        break;
    }
  }

  Future<void> _closeSocket() async {
    _phraseTimer?.cancel();
    _stopHeartbeat();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _startPhraseRotation() {
    _phraseTimer?.cancel();
    _phraseIndex = 0;
    _phraseTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _phraseIndex = (_phraseIndex + 1) % _waitingPhrases.length;
      if (state.queueStatus == CommunicationQueueStatus.searching) {
        state = state.copyWith(waitingPhrase: _waitingPhrases[_phraseIndex]);
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_channel == null) {
        return;
      }
      _sendSocketEvent(
          type: 'MATCH_PROGRESS', payload: {'phase': state.phase.name});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _sendSocketEvent(
      {required String type, required Map<String, dynamic> payload}) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    channel.sink.add(
      _repository.serializeEvent(
        type: type,
        payload: payload,
      ),
    );
  }

  void _scheduleReconnect() {
    final shouldReconnect =
        state.queueStatus == CommunicationQueueStatus.searching ||
            state.phase == CommunicationPhase.session ||
            state.queueStatus == CommunicationQueueStatus.queued;
    if (!shouldReconnect || _reconnectScheduled) {
      return;
    }

    _reconnectScheduled = true;
    _reconnectAttempts += 1;
    final delaySeconds = _reconnectAttempts > 5 ? 5 : _reconnectAttempts;

    Future<void>.delayed(Duration(seconds: delaySeconds), () async {
      _reconnectScheduled = false;
      if (_channel != null) {
        return;
      }
      try {
        await _connectSocketIfNeeded();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  Future<void> _ensureWebRtcReady() async {
    await _webRtc.initialize(
      onIceCandidate: (candidate) async {
        _sendSocketEvent(type: 'WEBRTC_ICE_CANDIDATE', payload: candidate);
      },
    );
    await _webRtc.ensureAudioTrack();
  }

  Future<void> _handleWebRtcOffer(Map<String, dynamic> payload) async {
    try {
      await _ensureWebRtcReady();
      final signal = _extractSignalPayload(payload);
      final answer = await _webRtc.createAnswer(signal);
      _sendSocketEvent(type: 'WEBRTC_ANSWER', payload: answer);
      state = state.copyWith(callSignalStatus: 'answer_sent');
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString(), callSignalStatus: 'answer_failed');
    }
  }

  Future<void> _handleWebRtcAnswer(Map<String, dynamic> payload) async {
    try {
      final signal = _extractSignalPayload(payload);
      await _webRtc.setRemoteDescription(signal);
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString(),
          callSignalStatus: 'answer_apply_failed');
    }
  }

  Future<void> _handleWebRtcIce(Map<String, dynamic> payload) async {
    try {
      final signal = _extractSignalPayload(payload);
      await _webRtc.addIceCandidate(signal);
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString(), callSignalStatus: 'ice_failed');
    }
  }

  Future<void> _autoStartAudioSignaling(Map<String, dynamic> payload) async {
    try {
      final me = await ref.read(meProvider.future);
      final peerId = payload['peer_id'] as int? ?? 0;

      // Choose a deterministic initiator to avoid both peers generating offers.
      if (peerId <= 0 || me.id >= peerId) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (state.phase != CommunicationPhase.session ||
          state.session?.sessionType != 'audio') {
        return;
      }

      await inviteCall();
    } catch (_) {
      // Keep manual invite fallback available if auto signaling fails.
    }
  }

  Map<String, dynamic> _extractSignalPayload(Map<String, dynamic> payload) {
    final nested = payload['session_signal'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return payload;
  }

  bool _rememberMessageId(int messageId) {
    if (_seenMessageIds.contains(messageId)) {
      return false;
    }
    _seenMessageIds.add(messageId);
    _seenMessageOrder.addLast(messageId);
    while (_seenMessageOrder.length > 512) {
      final expired = _seenMessageOrder.removeFirst();
      _seenMessageIds.remove(expired);
    }
    return true;
  }
}
