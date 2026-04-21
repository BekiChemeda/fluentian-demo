import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef IceCandidateCallback = Future<void> Function(Map<String, dynamic> candidate);

class WebRtcCallService {
  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  IceCandidateCallback? _onIceCandidate;

  bool get isReady => _peerConnection != null;

  Future<void> initialize({required IceCandidateCallback onIceCandidate}) async {
    _onIceCandidate = onIceCandidate;
    _peerConnection ??= await createPeerConnection(_iceConfig);

    _peerConnection?.onIceCandidate = (candidate) {
      final cb = _onIceCandidate;
      if (cb == null || candidate.candidate == null) {
        return;
      }
      unawaited(
        cb({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }),
      );
    };

    _peerConnection?.onConnectionState = (_) {};
  }

  Future<void> ensureAudioTrack() async {
    if (_localStream != null) {
      return;
    }

    final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
    _localStream = stream;
    final peer = _peerConnection;
    if (peer == null) {
      return;
    }

    for (final track in stream.getAudioTracks()) {
      await peer.addTrack(track, stream);
    }
  }

  Future<Map<String, dynamic>> createOffer() async {
    final peer = _peerConnection;
    if (peer == null) {
      throw StateError('WebRTC peer connection not initialized');
    }

    await ensureAudioTrack();
    final offer = await peer.createOffer();
    await peer.setLocalDescription(offer);
    return {
      'type': offer.type,
      'sdp': offer.sdp,
    };
  }

  Future<Map<String, dynamic>> createAnswer(Map<String, dynamic> remoteOffer) async {
    final peer = _peerConnection;
    if (peer == null) {
      throw StateError('WebRTC peer connection not initialized');
    }

    await ensureAudioTrack();
    await setRemoteDescription(remoteOffer);
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    return {
      'type': answer.type,
      'sdp': answer.sdp,
    };
  }

  Future<void> setRemoteDescription(Map<String, dynamic> signal) async {
    final peer = _peerConnection;
    if (peer == null) {
      throw StateError('WebRTC peer connection not initialized');
    }

    final type = signal['type'] as String?;
    final sdp = signal['sdp'] as String?;
    if (type == null || sdp == null || type.isEmpty || sdp.isEmpty) {
      return;
    }

    await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
  }

  Future<void> addIceCandidate(Map<String, dynamic> signal) async {
    final peer = _peerConnection;
    if (peer == null) {
      return;
    }

    final candidate = signal['candidate'] as String?;
    if (candidate == null || candidate.isEmpty) {
      return;
    }

    final sdpMid = signal['sdpMid'] as String?;
    final mLine = signal['sdpMLineIndex'];
    final index = mLine is int ? mLine : int.tryParse('$mLine');
    if (index == null) {
      return;
    }

    await peer.addCandidate(RTCIceCandidate(candidate, sdpMid, index));
  }

  Future<void> setMuted(bool muted) async {
    final stream = _localStream;
    if (stream == null) {
      return;
    }

    for (final track in stream.getAudioTracks()) {
      track.enabled = !muted;
    }
  }

  Future<void> resetPeer() async {
    await _peerConnection?.close();
    _peerConnection = null;
  }

  Future<void> dispose() async {
    await _peerConnection?.close();
    _peerConnection = null;
    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
    }
    _localStream = null;
    _onIceCandidate = null;
  }
}