import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/community_repository.dart';
import 'matching_screen.dart';
import '../ui_lab/audio_call_screen.dart';

class ChatHubScreen extends ConsumerStatefulWidget {
  const ChatHubScreen({
    super.key,
    this.initialTabIndex = 0,
    this.startWithCulturalMode = false,
    this.initialAiPrompt,
  });

  final int initialTabIndex;
  final bool startWithCulturalMode;
  final String? initialAiPrompt;

  @override
  ConsumerState<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends ConsumerState<ChatHubScreen> {
  final _peerMessages = <_Message>[];
  final _aiMessages = <_Message>[];

  final _peerController = TextEditingController();
  final _aiController = TextEditingController();
  final _peerScroll = ScrollController();
  final _aiScroll = ScrollController();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();

  Timer? _matchPoll;
  Timer? _chatPoll;

  int? _matchedId;
  String? _matchedEmail;
  String _matchStatus = 'idle';

  bool _peerTyping = false;
  bool _aiTyping = false;
  bool _listening = false;
  bool _voiceSendInFlight = false;
  bool _continuousHandsFree = false;
  String _mode = 'Text';
  String? _aiStatus;
  Timer? _nextListenTimer;
  int _activeTab = 0;
  bool _aiConversationInitialized = false;
  bool _culturalMode = false;
  String _baseLanguage = 'English';
  TabController? _tabController;
  final Stopwatch _audioCaptureWatch = Stopwatch();
  bool _initialTabApplied = false;
  bool _initialPromptSent = false;

  static const _culturalTopics = [
    'Food',
    'Greetings',
    'Lifestyle',
    'Traditions'
  ];

  @override
  void initState() {
    super.initState();
    _culturalMode = widget.startWithCulturalMode;
    _bootstrapMatchStatus();
    _configureTts();
    _bootstrapBaseLanguage();
  }

  Future<void> _bootstrapBaseLanguage() async {
    try {
      final me = await ref.read(meProvider.future);
      if (!mounted) return;
      setState(() {
        _baseLanguage = me.nativeLanguage == 'Amharic' ? 'Amharic' : 'English';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _matchPoll?.cancel();
    _chatPoll?.cancel();
    _nextListenTimer?.cancel();
    _peerController.dispose();
    _aiController.dispose();
    _peerScroll.dispose();
    _aiScroll.dispose();
    _speech.stop();
    _tts.stop();
    _tabController?.removeListener(_handleTabControllerTick);
    super.dispose();
  }

  void _handleTabControllerTick() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    if (!mounted) return;

    if (_activeTab != controller.index) {
      setState(() => _activeTab = controller.index);
    }

    if (controller.index == 1) {
      _ensureAiConversationInitialized();
    }
  }

  void _bindTabController(TabController controller) {
    if (_tabController == controller) return;
    _tabController?.removeListener(_handleTabControllerTick);
    _tabController = controller;
    _tabController?.addListener(_handleTabControllerTick);
    _activeTab = controller.index;

    if (!_initialTabApplied && widget.initialTabIndex == 1 && controller.length > 1) {
      _initialTabApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        controller.animateTo(1);
      });
    }

    if (_activeTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureAiConversationInitialized();
      });
    }
  }

  void _ensureAiConversationInitialized() {
    if (_aiConversationInitialized) return;
    _aiConversationInitialized = true;
    setState(() {
      _aiMessages.add(
        const _Message(
          'Bonjour! Je suis votre coach IA. Ecrivez ou parlez, et je vous aiderai en francais.',
          false,
        ),
      );
    });
    _scrollToBottom(_aiScroll);

    final initialPrompt = widget.initialAiPrompt?.trim();
    if (!_initialPromptSent && initialPrompt != null && initialPrompt.isNotEmpty) {
      _initialPromptSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sendAi(inputText: initialPrompt);
      });
    }
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _bootstrapMatchStatus() async {
    await _refreshMatchStatus();
    _matchPoll?.cancel();
    _matchPoll = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshMatchStatus(),
    );
  }

  Future<void> _refreshMatchStatus() async {
    try {
      final data = await ref.read(communityRepositoryProvider).matchStatus();
      if (!mounted) return;
      final status = (data['status'] as String?) ?? 'idle';
      final peer = data['peer'] as Map<String, dynamic>?;
      setState(() {
        _matchStatus = status;
        if (peer != null) {
          _matchedId = peer['id'] as int;
          _matchedEmail = peer['email'] as String?;
        } else if (status != 'matched') {
          _matchedId = null;
          _matchedEmail = null;
        }
      });

      if (_matchedId != null) {
        _chatPoll?.cancel();
        _chatPoll = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _refreshPeerMessages(),
        );
        await _refreshPeerMessages();
      }
    } catch (_) {}
  }

  Future<void> _startRandomMatch() async {
    setState(() => _peerTyping = true);
    try {
      final res = await ref.read(communityRepositoryProvider).findMatch();
      if (!mounted) return;
      setState(() {
        _matchedId = res['id'] as int;
        _matchedEmail = res['email'] as String?;
        _matchStatus = 'matched';
      });
      await _refreshPeerMessages();
    } catch (_) {
      if (!mounted) return;
      setState(() => _matchStatus = 'searching');
    } finally {
      if (mounted) {
        setState(() => _peerTyping = false);
      }
    }
  }

  Future<void> _leaveMatch() async {
    try {
      await ref.read(communityRepositoryProvider).leaveMatch();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _matchedId = null;
      _matchedEmail = null;
      _matchStatus = 'idle';
      _peerMessages.clear();
    });
  }

  Future<void> _refreshPeerMessages() async {
    final peerId = _matchedId;
    if (peerId == null) return;
    try {
      final items =
          await ref.read(communityRepositoryProvider).listMessages(peerId);
      final me = await ref.read(meProvider.future);
      if (!mounted) return;
      setState(() {
        _peerMessages
          ..clear()
          ..addAll(
            items
                .map(
                  (item) => _Message(
                    (item['body'] as String?) ?? '',
                    (item['sender_id'] as int?) == me.id,
                  ),
                )
                .toList(),
          );
      });
      _scrollToBottom(_peerScroll);
    } catch (_) {}
  }

  Future<void> _sendPeer() async {
    final text = _peerController.text.trim();
    final peerId = _matchedId;
    if (text.isEmpty || peerId == null) return;

    setState(() {
      _peerMessages.add(_Message(text, true));
      _peerTyping = true;
      _peerController.clear();
    });
    _scrollToBottom(_peerScroll);

    try {
      await ref
          .read(communityRepositoryProvider)
          .sendMessage(receiverId: peerId, body: text);
      await ref.read(analyticsServiceProvider).logEvent(
        'peer_message_sent',
        properties: {'length': text.length},
      );
      await _refreshPeerMessages();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _peerMessages.add(
          const _Message(
            'Message failed. Please try again.',
            false,
            isSystem: true,
          ),
        );
      });
    }

    if (!mounted) return;
    setState(() => _peerTyping = false);
  }

  Future<void> _sendAi({String? inputText, bool fromVoice = false}) async {
    final text = (inputText ?? _aiController.text).trim();
    if (text.isEmpty) return;
    final userIndex = _aiMessages.length;

    setState(() {
      _aiMessages.add(_Message(text, true));
      _aiTyping = true;
      _aiController.clear();
      _aiStatus = null;
    });
    _scrollToBottom(_aiScroll);

    try {
      final aiRes = await ref.read(communityRepositoryProvider).aiChat(
            text,
            history: _buildAiHistory(),
          );
      await ref.read(analyticsServiceProvider).logEvent(
        'ai_message_sent',
        properties: {
          'from_voice': fromVoice,
          'input_length': text.length,
          'success': aiRes.success,
        },
      );

      if (!mounted) return;
      setState(() {
        if (aiRes.corrected &&
            aiRes.correction != null &&
            aiRes.correction!.trim().isNotEmpty) {
          final original = _aiMessages[userIndex];
          _aiMessages[userIndex] =
              original.copyWith(correctionHint: aiRes.correction!.trim());
        }

        _aiMessages.add(_Message(aiRes.reply, false));
        _aiTyping = false;

        if (!aiRes.success) {
          _aiStatus =
              aiRes.errorMessage ?? 'AI coach is running in fallback mode.';
        }
      });
      _scrollToBottom(_aiScroll);

      if (_mode == 'Audio') {
        await _speak(aiRes.reply);
      }

      if (_continuousHandsFree && fromVoice && mounted) {
        _scheduleNextListen();
      }
    } on DioException catch (e) {
      final friendly = _friendlyApiError(e);
      if (!mounted) return;
      setState(() {
        _aiMessages.add(_Message(friendly, false, isSystem: true));
        _aiTyping = false;
        _aiStatus = friendly;
      });
      if (_mode == 'Audio' || fromVoice) {
        await _speak(friendly);
      }

      if (_continuousHandsFree && fromVoice && mounted) {
        _scheduleNextListen();
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _aiMessages.add(
          const _Message(
            'AI response format was invalid. Please retry.',
            false,
            isSystem: true,
          ),
        );
        _aiTyping = false;
        _aiStatus = 'Invalid AI response received from backend.';
      });

      if (_continuousHandsFree && fromVoice && mounted) {
        _scheduleNextListen();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiMessages.add(
          const _Message(
            'Desole, je ne peux pas repondre pour le moment.',
            false,
            isSystem: true,
          ),
        );
        _aiTyping = false;
        _aiStatus = 'Unexpected error while contacting AI coach.';
      });

      if (_continuousHandsFree && fromVoice && mounted) {
        _scheduleNextListen();
      }
    }
  }

  List<AiChatTurn> _buildAiHistory() {
    final history = _aiMessages
        .where((item) => !item.isSystem)
        .map(
          (item) => AiChatTurn(
            role: item.mine ? 'user' : 'assistant',
            message: item.text,
          ),
        )
        .toList();

    if (history.length > 12) {
      return history.sublist(history.length - 12);
    }
    return history;
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  String _friendlyApiError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) {
      return 'Session expired. Please log in again.';
    }
    if (code == 422) {
      return 'Message validation failed. Try a shorter sentence.';
    }
    if (code != null && code >= 500) {
      return 'Backend AI service is unavailable right now.';
    }
    return 'Network issue while reaching AI coach.';
  }

  Future<void> _startListeningCycle() async {
    if (_aiTyping || _voiceSendInFlight || _listening || _mode != 'Audio') {
      return;
    }

    final available = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _aiStatus = 'Microphone error: ${error.errorMsg}';
        });

        if (_continuousHandsFree) {
          _scheduleNextListen(delay: const Duration(seconds: 1));
        }
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );

    if (!available) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _aiStatus =
            'Microphone permission is unavailable. Enable it in app settings.';
      });
      return;
    }

    setState(() {
      _listening = true;
      _aiStatus = 'Listening... speak in French.';
    });

    await _speech.listen(
      localeId: 'fr_FR',
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      onResult: (result) async {
        final recognized = result.recognizedWords.trim();
        _aiController.text = recognized;

        if (!result.finalResult || recognized.isEmpty || _voiceSendInFlight) {
          return;
        }

        _voiceSendInFlight = true;
        await _speech.stop();
        if (!mounted) return;
        setState(() {
          _listening = false;
          _aiStatus = 'Sending voice message...';
        });

        try {
          await _sendAi(inputText: recognized, fromVoice: true);
        } finally {
          _voiceSendInFlight = false;
          if (mounted) {
            setState(() {
              _aiStatus = _continuousHandsFree
                  ? 'Voice message sent. Continuing hands-free...'
                  : 'Voice message sent. Tap mic to speak again.';
            });
          }
        }
      },
    );
  }

  void _scheduleNextListen(
      {Duration delay = const Duration(milliseconds: 650)}) {
    _nextListenTimer?.cancel();
    _nextListenTimer = Timer(delay, () {
      if (!mounted || !_continuousHandsFree || _mode != 'Audio') {
        return;
      }
      _startListeningCycle();
    });
  }

  Future<void> _toggleHandsFreeListen() async {
    if (_continuousHandsFree || _listening) {
      _nextListenTimer?.cancel();
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _continuousHandsFree = false;
        _listening = false;
        _aiStatus = 'Hands-free stopped.';
      });
      return;
    }

    if (_aiTyping) {
      setState(() {
        _aiStatus = 'Please wait for the current AI response.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _continuousHandsFree = true;
      _aiStatus = 'Hands-free started. Speak in French.';
    });
    await _startListeningCycle();
  }

  void _scrollToBottom(ScrollController controller) {
    if (!controller.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleCallAction() async {
    if (_activeTab == 1) {
      _ensureAiConversationInitialized();

      await ref.read(analyticsServiceProvider).logEvent(
        'voice_chat_opened',
        properties: {'from': 'chat_hub', 'type': 'ai'},
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AudioCallScreen(
            isAi: true,
            peerLabel: 'Fluentian AI',
          ),
        ),
      );
      return;
    }

    await ref.read(analyticsServiceProvider).logEvent(
      'matching_opened',
      properties: {'from': 'chat_hub'},
    );

    if (!mounted) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const MatchingScreen(),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _matchedId = result['id'] as int?;
      _matchedEmail = result['email'] as String?;
      _matchStatus = _matchedId != null ? 'matched' : _matchStatus;
    });
    await _refreshPeerMessages();
  }

  Future<void> _openAttachmentPicker(bool isAi) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attach',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('Image'),
                  subtitle: const Text('Send a photo attachment'),
                  onTap: () => Navigator.of(context).pop('image'),
                ),
                ListTile(
                  leading: const Icon(Icons.mic_rounded),
                  title: const Text('Audio message'),
                  subtitle: const Text('Record and send a voice message'),
                  onTap: () => Navigator.of(context).pop('audio'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    String attachmentLabel;
    if (selected == 'image') {
      attachmentLabel = 'sample_image.jpg';
    } else {
      attachmentLabel = await _captureAudioAttachmentLength() ?? '00:00';
    }

    if (!mounted) return;

    if (!isAi && _matchedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Find a personal match before sending attachments.')),
      );
      return;
    }

    setState(() {
      final target = isAi ? _aiMessages : _peerMessages;
      target.add(
        _Message(
          selected == 'image' ? 'Image attachment' : 'Audio message',
          true,
          kind: selected == 'image' ? _MessageKind.image : _MessageKind.audio,
          attachmentLabel: attachmentLabel,
        ),
      );
    });

    _scrollToBottom(isAi ? _aiScroll : _peerScroll);

    if (!isAi) return;
    setState(() {
      _aiMessages.add(
        const _Message(
          'Attachment received. Ask me to describe, correct, or summarize it.',
          false,
        ),
      );
    });
    _scrollToBottom(_aiScroll);
  }

  Future<String?> _captureAudioAttachmentLength() async {
    _nextListenTimer?.cancel();
    await _speech.stop();
    if (!mounted) return null;

    setState(() {
      _listening = false;
      _aiStatus = 'Recording voice note...';
    });

    final completer = Completer<String?>();
    var completed = false;

    void completeOnce(String? value) {
      if (completed) return;
      completed = true;
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    try {
      final available = await _speech.initialize(
        onError: (_) => completeOnce(null),
        onStatus: (status) {
          if (status == 'notListening') {
            if (_audioCaptureWatch.isRunning) {
              _audioCaptureWatch.stop();
            }
            final elapsed = _audioCaptureWatch.elapsed;
            completeOnce(elapsed > Duration.zero ? _formatDuration(elapsed) : null);
          }
        },
      );

      if (!available) {
        if (mounted) {
          setState(() {
            _aiStatus = 'Microphone permission is unavailable.';
          });
        }
        return null;
      }

      _audioCaptureWatch
        ..reset()
        ..start();

      await _speech.listen(
        localeId: 'fr_FR',
        listenOptions: stt.SpeechListenOptions(partialResults: false),
        listenFor: const Duration(seconds: 20),
        onResult: (result) async {
          if (!result.finalResult) return;
          if (_audioCaptureWatch.isRunning) {
            _audioCaptureWatch.stop();
          }
          await _speech.stop();
          final elapsed = _audioCaptureWatch.elapsed;
          completeOnce(elapsed > Duration.zero ? _formatDuration(elapsed) : null);
        },
      );

      final value = await completer.future.timeout(
        const Duration(seconds: 22),
        onTimeout: () {
          if (_audioCaptureWatch.isRunning) {
            _audioCaptureWatch.stop();
          }
          return _audioCaptureWatch.elapsed > Duration.zero
              ? _formatDuration(_audioCaptureWatch.elapsed)
              : null;
        },
      );

      if (mounted) {
        setState(() {
          _aiStatus = value == null ? 'Voice note capture failed.' : 'Voice note captured.';
        });
      }
      return value;
    } catch (_) {
      return null;
    } finally {
      _audioCaptureWatch.stop();
    }
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds <= 0 ? 1 : value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _onAiQuickReply(String value) async {
    if (value.startsWith('Culture: ')) {
      final topic = value.replaceFirst('Culture: ', '');
      _aiController.text =
          'Let us do a short cultural exchange about $topic between France and Ethiopia. Explain key phrases in $_baseLanguage and then continue in French.';
    } else {
      _aiController.text = value;
    }
    await _sendAi();
  }

  Future<void> _handleMessageAction({
    required bool isAi,
    required String action,
    required _Message message,
  }) async {
    if (!isAi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Translate/Explain/Correct is available in AI chat.')),
      );
      return;
    }

    String prompt;
    if (action == 'translate') {
      prompt =
          'Translate this message into $_baseLanguage while keeping tone and context: "${message.text}"';
    } else if (action == 'explain') {
      prompt =
          'Explain this French message in simple $_baseLanguage with cultural context if relevant: "${message.text}"';
    } else {
      prompt =
          'Correct this message and explain mistakes in $_baseLanguage, then provide a better French version: "${message.text}"';
    }
    await _sendAi(inputText: prompt);
  }

  List<String> _buildAiQuickReplies() {
    final base = [
      'Correct this sentence',
      'Give me 3 practice questions',
      'Explain in $_baseLanguage',
    ];
    if (_culturalMode) {
      return [
        ...base,
        ..._culturalTopics.map((item) => 'Culture: $item'),
      ];
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          _bindTabController(DefaultTabController.of(context));
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chat Hub'),
              actions: [
                IconButton(
                  tooltip: _activeTab == 1
                      ? 'Start AI voice chat'
                      : 'Call matched person',
                  onPressed: _handleCallAction,
                  icon: const Icon(Icons.call_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _mode,
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(value: 'Text', child: Text('Text')),
                        DropdownMenuItem(value: 'Audio', child: Text('Audio')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _mode = value;
                          if (value != 'Audio') {
                            _continuousHandsFree = false;
                            _listening = false;
                            _speech.stop();
                            _nextListenTimer?.cancel();
                            _aiStatus = null;
                          } else {
                            _aiStatus =
                                'Hands-free mode enabled. Tap mic to start.';
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                onTap: (index) {
                  setState(() => _activeTab = index);
                  if (index == 1) {
                    _ensureAiConversationInitialized();
                  }
                },
                tabs: const [
                  Tab(text: 'Personal'),
                  Tab(text: 'AI'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _ChatPane(
                  messages: _peerMessages,
                  controller: _peerController,
                  scrollController: _peerScroll,
                  hint: _matchedId == null
                      ? 'Type a message...'
                      : 'Type a message...',
                  onSend: _sendPeer,
                  onAttach: () => _openAttachmentPicker(false),
                  typing: _peerTyping,
                  isAiMode: false,
                  emptyTitle: _matchedId == null
                      ? 'No personal match yet'
                      : 'No messages yet',
                  emptySubtitle: _matchedId == null
                      ? 'Tap call to open matching and connect with a learner.'
                      : 'Say hi to start your conversation.',
                  topHeader: _PeerMatchHeader(
                    status: _matchStatus,
                    matchedEmail: _matchedEmail,
                    onFind: _startRandomMatch,
                    onLeave: _leaveMatch,
                  ),
                  canSend: _matchedId != null,
                ),
                _ChatPane(
                  messages: _aiMessages,
                  controller: _aiController,
                  scrollController: _aiScroll,
                  hint: 'Ask anything...',
                  onSend: () => _sendAi(),
                  onAttach: () => _openAttachmentPicker(true),
                  quickReplies: _buildAiQuickReplies(),
                  onQuickReplyTap: _onAiQuickReply,
                  typing: _aiTyping,
                  isAiMode: true,
                  emptyTitle: 'Start AI conversation',
                  emptySubtitle:
                      'Ask for corrections, examples, or voice practice.',
                  topHeader: _AiChatHeader(
                    mode: _mode,
                    listening: _listening,
                    continuousHandsFree: _continuousHandsFree,
                    culturalMode: _culturalMode,
                    baseLanguage: _baseLanguage,
                    statusText: _aiStatus,
                    onToggleListen: _toggleHandsFreeListen,
                    onToggleCultural: () {
                      setState(() => _culturalMode = !_culturalMode);
                    },
                  ),
                  canSend: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.hint,
    required this.onSend,
    required this.onAttach,
    required this.typing,
    required this.isAiMode,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.topHeader,
    required this.canSend,
    this.quickReplies = const [],
    this.onQuickReplyTap,
  });

  final List<_Message> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final String hint;
  final Future<void> Function() onSend;
  final Future<void> Function() onAttach;
  final bool typing;
  final bool isAiMode;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget topHeader;
  final bool canSend;
  final List<String> quickReplies;
  final Future<void> Function(String value)? onQuickReplyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        topHeader,
        Expanded(
          child: SelectionArea(
            child: messages.isEmpty
                ? _EmptyChatState(title: emptyTitle, subtitle: emptySubtitle)
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (typing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (typing && index == messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Typing...',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }
                      final item = messages[index];
                      return _ChatBubble(
                        isAiMode: isAiMode,
                        text: item.text,
                        mine: item.mine,
                        correctionOfUser: item.correctionOfUser,
                        isSystem: item.isSystem,
                        correctionHint: item.correctionHint,
                        kind: item.kind,
                        attachmentLabel: item.attachmentLabel,
                        onActionSelected: (action) async => (context
                                .findAncestorStateOfType<_ChatHubScreenState>())
                            ?._handleMessageAction(
                          isAi: isAiMode,
                          action: action,
                          message: item,
                        ),
                      );
                    },
                  ),
          ),
        ),
        if (quickReplies.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final value = quickReplies[index];
                return ActionChip(
                  label: Text(value),
                  onPressed: onQuickReplyTap == null
                      ? null
                      : () => onQuickReplyTap!(value),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: quickReplies.length,
            ),
          ),
        if (quickReplies.isNotEmpty) const SizedBox(height: 6),
        _Composer(
          hint: hint,
          controller: controller,
          onSend: onSend,
          onAttach: onAttach,
          enabled: canSend,
        ),
      ],
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textMuted, size: 34),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageKind { text, image, audio }

class _Message {
  const _Message(
    this.text,
    this.mine, {
    this.correctionOfUser = false,
    this.isSystem = false,
    this.correctionHint,
    this.kind = _MessageKind.text,
    this.attachmentLabel,
  });

  final String text;
  final bool mine;
  final bool correctionOfUser;
  final bool isSystem;
  final String? correctionHint;
  final _MessageKind kind;
  final String? attachmentLabel;

  _Message copyWith({
    String? text,
    bool? mine,
    bool? correctionOfUser,
    bool? isSystem,
    String? correctionHint,
    _MessageKind? kind,
    String? attachmentLabel,
  }) {
    return _Message(
      text ?? this.text,
      mine ?? this.mine,
      correctionOfUser: correctionOfUser ?? this.correctionOfUser,
      isSystem: isSystem ?? this.isSystem,
      correctionHint: correctionHint ?? this.correctionHint,
      kind: kind ?? this.kind,
      attachmentLabel: attachmentLabel ?? this.attachmentLabel,
    );
  }
}

class _ChatBubble extends StatefulWidget {
  const _ChatBubble({
    required this.isAiMode,
    required this.text,
    required this.mine,
    required this.correctionOfUser,
    required this.isSystem,
    required this.correctionHint,
    required this.kind,
    required this.attachmentLabel,
    required this.onActionSelected,
  });

  final bool isAiMode;
  final Future<void> Function(String action) onActionSelected;

  final String text;
  final bool mine;
  final bool correctionOfUser;
  final bool isSystem;
  final String? correctionHint;
  final _MessageKind kind;
  final String? attachmentLabel;

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _audioPlaying = false;

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _showMessageActions() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
              if (widget.isAiMode) ...[
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: const Text('Translate'),
                  onTap: () => Navigator.of(context).pop('translate'),
                ),
                ListTile(
                  leading: const Icon(Icons.lightbulb_rounded),
                  title: const Text('Explain'),
                  onTap: () => Navigator.of(context).pop('explain'),
                ),
                ListTile(
                  leading: const Icon(Icons.spellcheck_rounded),
                  title: const Text('Correct'),
                  onTap: () => Navigator.of(context).pop('correct'),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected == 'copy') {
      await _copy(context, widget.text, 'Message');
      return;
    }
    await widget.onActionSelected(selected);
  }

  Future<void> _openImagePreview() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_rounded,
                        size: 72, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      widget.attachmentLabel ?? 'image.jpg',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            widget.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: _showMessageActions,
            onTap: widget.kind == _MessageKind.image ? _openImagePreview : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: widget.isSystem
                    ? const Color(0xFFFFF7ED)
                    : widget.correctionOfUser
                        ? const Color(0xFFDCFCE7)
                        : (widget.mine ? AppColors.primary : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: widget.correctionOfUser
                    ? Border.all(color: AppColors.secondary)
                    : widget.isSystem
                        ? Border.all(color: AppColors.warning)
                        : Border.all(color: AppColors.border),
              ),
              child: _buildBubbleContent(),
            ),
          ),
          if (widget.mine &&
              widget.correctionHint != null &&
              widget.correctionHint!.trim().isNotEmpty)
            GestureDetector(
              onLongPress: _showMessageActions,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: SelectableText(
                  widget.correctionHint!,
                  style: const TextStyle(
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBubbleContent() {
    final textColor = widget.mine ? Colors.white : AppColors.text;
    if (widget.kind == _MessageKind.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              height: 130,
              color: widget.mine
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.surfaceMuted,
              child: Icon(Icons.image_rounded, color: textColor, size: 36),
            ),
          ),
          const SizedBox(height: 8),
          Text(widget.attachmentLabel ?? 'image.jpg',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        ],
      );
    }

    if (widget.kind == _MessageKind.audio) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => setState(() => _audioPlaying = !_audioPlaying),
            icon: Icon(
              _audioPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: textColor,
            ),
          ),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: _audioPlaying ? 0.65 : 0.25,
              minHeight: 5,
              borderRadius: BorderRadius.circular(999),
              color: textColor,
              backgroundColor: widget.mine
                  ? Colors.white.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          const SizedBox(width: 8),
          Text(widget.attachmentLabel ?? '00:00',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        ],
      );
    }

    return SelectableText(
      widget.text,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.hint,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.enabled,
  });

  final String hint;
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final Future<void> Function() onAttach;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: enabled ? onAttach : null,
            icon: const Icon(Icons.attach_file_rounded),
            tooltip: 'Attach image or audio',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => enabled ? onSend() : null,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: ElevatedButton(
              onPressed: enabled ? onSend : null,
              child: const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerMatchHeader extends StatelessWidget {
  const _PeerMatchHeader({
    required this.status,
    required this.matchedEmail,
    required this.onFind,
    required this.onLeave,
  });

  final String status;
  final String? matchedEmail;
  final Future<void> Function() onFind;
  final Future<void> Function() onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              (matchedEmail ?? 'P').characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status == 'matched'
                  ? 'Matched with ${matchedEmail ?? 'partner'}'
                  : status == 'searching'
                      ? 'Looking for random match...'
                      : 'Join queue to find random learner',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (status == 'matched')
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Online',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (status != 'matched')
            ElevatedButton(onPressed: onFind, child: const Text('Find Match'))
          else
            OutlinedButton(onPressed: onLeave, child: const Text('Leave')),
        ],
      ),
    );
  }
}

class _AiChatHeader extends StatelessWidget {
  const _AiChatHeader({
    required this.mode,
    required this.listening,
    required this.continuousHandsFree,
    required this.culturalMode,
    required this.baseLanguage,
    required this.statusText,
    required this.onToggleListen,
    required this.onToggleCultural,
  });

  final String mode;
  final bool listening;
  final bool continuousHandsFree;
  final bool culturalMode;
  final String baseLanguage;
  final String? statusText;
  final Future<void> Function() onToggleListen;
  final VoidCallback onToggleCultural;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Coach IA: reponse en francais uniquement, sauf si vous demandez une explication en anglais ou amharique.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              if (mode == 'Audio')
                FilledButton.tonalIcon(
                  onPressed: onToggleListen,
                  icon: Icon(
                    (listening || continuousHandsFree)
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                  ),
                  label: Text(
                    (listening || continuousHandsFree) ? 'Stop' : 'Start',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                selected: culturalMode,
                onSelected: (_) => onToggleCultural(),
                label: Text(
                    culturalMode ? 'Cultural Mode ON' : 'Cultural Mode OFF'),
              ),
              Chip(
                label: Text('Base: $baseLanguage'),
                avatar: const Icon(Icons.language_rounded, size: 16),
              ),
            ],
          ),
          if (statusText != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
