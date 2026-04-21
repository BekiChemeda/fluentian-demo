import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/providers.dart';
import '../../../data/repositories/community_repository.dart';

class AudioCallScreen extends ConsumerStatefulWidget {
  const AudioCallScreen({
    super.key,
    this.isAi = false,
    this.peerLabel = 'Sara',
  });

  final bool isAi;
  final String peerLabel;

  @override
  ConsumerState<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends ConsumerState<AudioCallScreen> {
  late final Timer _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speaker = true;
  bool _captions = true;
  bool _aiListening = true;
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  bool _sttReady = false;
  bool _aiBusy = false;
  String _latestTranscript = '';
  String _latestAiReply = '';
  final List<AiChatTurn> _history = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds += 1);
    });

    if (widget.isAi) {
      _configureAiVoice();
    }
  }

  Future<void> _configureAiVoice() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _sttReady = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _aiListening = false;
          _latestAiReply = 'Microphone error: ${error.errorMsg}';
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening') {
          setState(() => _aiListening = false);
        }
      },
    );

    if (!_sttReady && mounted) {
      setState(() {
        _latestAiReply = 'Microphone permission is unavailable for AI call.';
      });
      return;
    }

    await _startListening();
  }

  @override
  void dispose() {
    _timer.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!widget.isAi || _muted || _aiBusy || !_sttReady || _aiListening) {
      return;
    }

    setState(() => _aiListening = true);
    await _speech.listen(
      localeId: 'fr_FR',
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      listenFor: const Duration(seconds: 20),
      onResult: (result) async {
        if (!mounted) return;
        setState(() => _latestTranscript = result.recognizedWords.trim());

        if (!result.finalResult || _latestTranscript.isEmpty || _aiBusy) {
          return;
        }

        await _speech.stop();
        if (!mounted) return;
        setState(() => _aiListening = false);
        await _sendToAi(_latestTranscript);
      },
    );
  }

  Future<void> _sendToAi(String utterance) async {
    _aiBusy = true;
    setState(() {
      _latestAiReply = 'AI is thinking...';
    });

    try {
      final reply = await ref.read(communityRepositoryProvider).aiChat(
            utterance,
            history: _history,
          );
      if (!mounted) return;

      _history.add(AiChatTurn(role: 'user', message: utterance));
      _history.add(AiChatTurn(role: 'assistant', message: reply.reply));
      if (_history.length > 14) {
        _history.removeRange(0, _history.length - 14);
      }

      setState(() {
        _latestAiReply = reply.reply;
        _aiListening = false;
      });

      if (!_muted) {
        await _tts.stop();
        await _tts.speak(reply.reply);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _latestAiReply = 'AI service is unavailable at the moment.';
      });
    } finally {
      _aiBusy = false;
      if (mounted && widget.isAi && !_muted) {
        await _startListening();
      }
    }
  }

  String _formattedTime() {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Session Summary',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 10),
              Text('Duration: ${_formattedTime()}'),
              Text(widget.isAi
                  ? 'AI feedback score: 92%'
                  : 'Fluency gain: +12 XP'),
              Text(widget.isAi
                  ? 'Pronunciation confidence: 88%'
                  : 'Pronunciation score: 82%'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F8B42), Color(0xFF103B24)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white)),
                    Text(
                      widget.isAi ? 'AI Voice Call' : 'French Voice Practice',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const Spacer(),
                const CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.record_voice_over_rounded,
                      size: 54, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connected to ${widget.peerLabel}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(_formattedTime(),
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
                if (widget.isAi) ...[
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: (_aiListening
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF47BDB1))
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _aiListening
                              ? Icons.hearing_rounded
                              : Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _aiListening ? 'Listening' : 'Speaking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SpeakingBars(active: !_aiListening),
                ],
                const SizedBox(height: 8),
                if (_captions)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      widget.isAi
                          ? (_latestAiReply.isNotEmpty
                              ? 'AI: $_latestAiReply'
                              : (_latestTranscript.isNotEmpty
                                  ? 'You: $_latestTranscript'
                                  : 'AI voice mode ready. Speak in French.'))
                          : 'Live: Bonjour! Comment ca va?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallControl(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      bg: _muted
                          ? const Color(0x66E14E4E)
                          : const Color(0x33FFFFFF),
                      onTap: () async {
                        final next = !_muted;
                        setState(() => _muted = next);
                        if (!widget.isAi) return;
                        if (next) {
                          await _speech.stop();
                          if (mounted) {
                            setState(() => _aiListening = false);
                          }
                        } else {
                          await _startListening();
                        }
                      },
                    ),
                    _CallControl(
                      icon: _speaker
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      bg: const Color(0x33FFFFFF),
                      onTap: () => setState(() => _speaker = !_speaker),
                    ),
                    _CallControl(
                      icon: Icons.closed_caption_rounded,
                      bg: _captions
                          ? const Color(0x66F7B500)
                          : const Color(0x33FFFFFF),
                      onTap: () => setState(() => _captions = !_captions),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE14E4E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakingBars extends StatefulWidget {
  const _SpeakingBars({required this.active});

  final bool active;

  @override
  State<_SpeakingBars> createState() => _SpeakingBarsState();
}

class _SpeakingBarsState extends State<_SpeakingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SpeakingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
    if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = widget.active ? _controller.value : 0.15;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final scale = 8 + ((index + 1) * 3 * value);
            return Container(
              width: 5,
              height: scale,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl(
      {required this.icon, required this.bg, required this.onTap});

  final IconData icon;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
