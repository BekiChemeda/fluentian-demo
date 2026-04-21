import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef IceCandidateCallback = Future<void> Function(
    Map<String, dynamic> candidate);

class WebRtcCallService {
  static Map<String, dynamic> _buildIceConfig() {
    final servers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
    ];

    const configuredServers = String.fromEnvironment(
      'WEBRTC_ICE_SERVERS_JSON',
      defaultValue: '',
    );
    if (configuredServers.isNotEmpty) {
      try {
        final decoded = jsonDecode(configuredServers);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              servers.add(
                  item.map((key, value) => MapEntry(key.toString(), value)));
            }
          }
        } else if (decoded is Map) {
          servers.add(
              decoded.map((key, value) => MapEntry(key.toString(), value)));
        }
      } catch (_) {
        // Keep the default STUN server if the JSON is invalid.
      }
    }

    final config = <String, dynamic>{'iceServers': servers};

    const transportPolicy = String.fromEnvironment(
      'WEBRTC_ICE_TRANSPORT_POLICY',
      defaultValue: '',
    );
    if (transportPolicy.isNotEmpty) {
      config['iceTransportPolicy'] = transportPolicy;
    }

    return config;
  }

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  IceCandidateCallback? _onIceCandidate;

  bool get isReady => _peerConnection != null;

  Future<void> initialize(
      {required IceCandidateCallback onIceCandidate}) async {
    _onIceCandidate = onIceCandidate;
    _peerConnection ??= await createPeerConnection(_buildIceConfig());

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

    if (_localStream != null) {
      await _attachLocalStreamToPeer();
    }
  }

  Future<void> _attachLocalStreamToPeer() async {
    final peer = _peerConnection;
    final stream = _localStream;
    if (peer == null || stream == null) {
      return;
    }

    for (final track in stream.getAudioTracks()) {
      final alreadyAttached = (await peer.getSenders()).any(
        (sender) => sender.track?.id == track.id,
      );
      if (!alreadyAttached) {
        await peer.addTrack(track, stream);
      }
    }
  }

  Future<void> ensureAudioTrack() async {
    if (_localStream != null) {
      await _attachLocalStreamToPeer();
      return;
    }

    final stream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
    _localStream = stream;
    await _attachLocalStreamToPeer();
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

  Future<Map<String, dynamic>> createAnswer(
      Map<String, dynamic> remoteOffer) async {
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
