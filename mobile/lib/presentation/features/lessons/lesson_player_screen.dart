import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/lesson_model.dart';
import '../../app/providers.dart';
import '../../widgets/answer_button.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key, required this.lessonId});

  final int lessonId;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen>
    with SingleTickerProviderStateMixin {
  int _blockIndex = 0;
  int _correctCount = 0;
  bool _isChecked = false;

  AnswerState _state = AnswerState.normal;
  String? _selected;
  List<String>? _orderedTokens;
  bool _explainFabLoading = false;
  bool _explainPanelOpen = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  final Map<String, _LessonExplainData> _explainCache = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _configureSpeechTools();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _configureSpeechTools() async {
    var sttReady = false;
    var ttsReady = false;

    try {
      sttReady = await _speech.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (_) {
      sttReady = false;
    }

    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      ttsReady = true;
    } catch (_) {
      ttsReady = false;
    }

    if (!mounted) return;
    setState(() {
      _speechReady = sttReady && ttsReady;
    });
  }

  Future<void> _runDialogueSpeechAssist(_LessonBlock block) async {
    if (block.type != _LessonBlockType.dialogue) {
      return;
    }
    if (!_speechReady || _isListening || _isSpeaking) {
      if (!_speechReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech tools are not available yet.')),
        );
      }
      return;
    }

    String? promptLine;
    for (final line in block.dialogue) {
      if (!line.mine && line.text.trim().isNotEmpty) {
        promptLine = line.text.trim();
      }
    }
    if (promptLine == null) {
      return;
    }

    setState(() => _isSpeaking = true);
    try {
      await _tts.stop();
      await _tts.speak(promptLine);
    } finally {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
    if (!mounted) return;

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: 'fr_FR',
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        final spoken = result.recognizedWords.trim();
        if (!mounted) return;
        if (spoken.isEmpty) {
          if (result.finalResult) {
            setState(() => _isListening = false);
          }
          return;
        }

        final lower = spoken.toLowerCase();
        String? bestChoice;
        for (final choice in block.choices) {
          final normalized = choice.trim().toLowerCase();
          if (normalized == lower) {
            bestChoice = choice;
            break;
          }
          if (lower.contains(normalized) || normalized.contains(lower)) {
            bestChoice = choice;
          }
        }

        if (bestChoice != null) {
          setState(() => _selected = bestChoice);
        }

        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
    );
  }

  bool _evaluateBlock(_LessonBlock block) {
    if (!block.hasQuestion) {
      return true;
    }

    switch (block.type) {
      case _LessonBlockType.dialogue:
      case _LessonBlockType.translationMcq:
        if (_selected == null) {
          return false;
        }
        return _selected!.trim().toLowerCase() ==
            block.answer.trim().toLowerCase();
      case _LessonBlockType.ordering:
        final ordered = _orderedTokens;
        if (ordered == null || ordered.isEmpty) {
          return false;
        }
        return ordered.join(' ').trim().toLowerCase() ==
            block.answer.trim().toLowerCase();
      case _LessonBlockType.sentence:
        return true;
    }
  }

  Future<void> _checkCurrentBlock(_LessonBlock block) async {
    final isCorrect = _evaluateBlock(block);
    setState(() {
      _state = isCorrect ? AnswerState.correct : AnswerState.wrong;
      _isChecked = true;
      if (isCorrect) {
        _correctCount += 1;
      }
    });

    if (!isCorrect && block.hasQuestion) {
      await _shakeController.forward(from: 0);
    }
  }

  void _resetForNextBlock() {
    setState(() {
      _selected = null;
      _orderedTokens = null;
      _state = AnswerState.normal;
      _isChecked = false;
    });
  }

  Future<void> _completeLesson(List<_LessonBlock> blocks) async {
    final ratio =
        blocks.isEmpty ? 0.0 : (_correctCount / blocks.length).clamp(0.0, 1.0);
    final score = (40 + (ratio * 60)).round();

    await ref
        .read(completionProvider.notifier)
        .completeLesson(widget.lessonId, score);
    if (!mounted) {
      return;
    }

    final percentage = (ratio * 100).round();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isDismissible: false,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lesson Completed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Accuracy: $percentage%'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).pop();
                },
                child: const Text('Back to Roadmap'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _explainCacheKey({
    required int lessonId,
    required int blockIndex,
    required String action,
    String? inlineContext,
  }) {
    return '$lessonId|$blockIndex|$action|${inlineContext ?? ''}';
  }

  Future<_LessonExplainData> _fetchExplanation({
    required LessonModel lesson,
    required _LessonBlock block,
    required int blockIndex,
    required String action,
    String? inlineContext,
  }) async {
    final me = await ref.read(meProvider.future);
    final baseLanguage = me.nativeLanguage == 'Amharic' ? 'Amharic' : 'English';
    final key = _explainCacheKey(
      lessonId: lesson.id,
      blockIndex: blockIndex,
      action: action,
      inlineContext: inlineContext,
    );

    final cached = _explainCache[key];
    if (cached != null) {
      return cached;
    }

    final data = await ref.read(lessonRepositoryProvider).explainLesson(
          lessonId: lesson.id,
          blockTitle: block.title,
          blockHint: block.hint,
          blockAnswer: block.answer,
          action: action,
          inlineContext: inlineContext,
        );
    final parsed = _LessonExplainData.fromApi(
      data: data,
      fallbackLanguage: baseLanguage,
    );
    _explainCache[key] = parsed;
    return parsed;
  }

  Future<void> _openExplainSheet({
    required LessonModel lesson,
    required _LessonBlock block,
    required int blockIndex,
    String? inlineContext,
  }) async {
    if (_explainFabLoading) return;
    setState(() {
      _explainFabLoading = true;
      _explainPanelOpen = true;
    });

    _LessonExplainData? data;
    String? error;
    try {
      data = await _fetchExplanation(
        lesson: lesson,
        block: block,
        blockIndex: blockIndex,
        action: 'default',
        inlineContext: inlineContext,
      );
    } catch (_) {
      error = 'Could not load explanation right now.';
    }

    if (!mounted) return;
    setState(() => _explainFabLoading = false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var localData = data;
        var localError = error;
        var localLoading = false;
        final followUpController = TextEditingController();

        Future<void> runAction(String action, {String? followUp}) async {
          (context as Element).markNeedsBuild();
          localLoading = true;
          localError = null;
          (context as Element).markNeedsBuild();
          try {
            localData = await _fetchExplanation(
              lesson: lesson,
              block: block,
              blockIndex: blockIndex,
              action: action,
              inlineContext: followUp ?? inlineContext,
            );
          } catch (_) {
            localError = 'Could not refresh explanation.';
          } finally {
            localLoading = false;
            (context as Element).markNeedsBuild();
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runActionInModal(String action,
                {String? followUp}) async {
              setModalState(() {
                localLoading = true;
                localError = null;
              });
              try {
                localData = await _fetchExplanation(
                  lesson: lesson,
                  block: block,
                  blockIndex: blockIndex,
                  action: action,
                  inlineContext: followUp ?? inlineContext,
                );
              } catch (_) {
                localError = 'Could not refresh explanation.';
              } finally {
                setModalState(() => localLoading = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Explain this lesson',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          )
                        ],
                      ),
                      if (localLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (localError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(localError!,
                              style: const TextStyle(color: AppColors.error)),
                        )
                      else if (localData != null) ...[
                        Text(
                          localData!.simple,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Examples',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        ...localData!.examples.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $item'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Key Rules',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        ...localData!.rules.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $item'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('Simplify more'),
                            onPressed: localLoading
                                ? null
                                : () => runActionInModal('simplify'),
                          ),
                          ActionChip(
                            label: const Text('Give more examples'),
                            onPressed: localLoading
                                ? null
                                : () => runActionInModal('examples'),
                          ),
                          ActionChip(
                            label: const Text('Quiz me'),
                            onPressed: localLoading
                                ? null
                                : () => runActionInModal('quiz'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: followUpController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Ask a follow-up question...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: localLoading
                              ? null
                              : () => runActionInModal(
                                    'examples',
                                    followUp: followUpController.text.trim(),
                                  ),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Ask'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _explainPanelOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fluentian Lesson')),
      floatingActionButton: lessonAsync.maybeWhen(
        data: (lessons) {
          final lesson = lessons.firstWhere((l) => l.id == widget.lessonId);
          final blocks = _buildBlocksFromContent(lesson.content);
          final safeIndex = _blockIndex.clamp(0, blocks.length - 1);
          final block = blocks[safeIndex];
          return FloatingActionButton(
            heroTag: 'lessonExplainFab_${widget.lessonId}',
            backgroundColor: AppColors.secondary,
            onPressed: _explainFabLoading
                ? null
                : () => _openExplainSheet(
                      lesson: lesson,
                      block: block,
                      blockIndex: safeIndex,
                    ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _explainFabLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _explainPanelOpen
                          ? Icons.chat_bubble_rounded
                          : Icons.auto_awesome_rounded,
                      key: ValueKey<bool>(_explainPanelOpen),
                      color: Colors.white,
                    ),
            ),
          );
        },
        orElse: () => null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAFBF0), Color(0xFFFDF6EA)],
          ),
        ),
        child: lessonAsync.when(
          data: (lessons) {
            final lesson = lessons.firstWhere((l) => l.id == widget.lessonId);
            final blocks = _buildBlocksFromContent(lesson.content);
            final block = blocks[_blockIndex];
            final progress =
                (_blockIndex + (_isChecked ? 1 : 0)) / blocks.length;

            _orderedTokens ??=
                block.type == _LessonBlockType.ordering ? <String>[] : null;

            final topExplanation =
                block.explanationPlacement == _ExplanationPlacement.top;
            final middleExplanation =
                block.explanationPlacement == _ExplanationPlacement.middle;
            final bottomExplanation =
                block.explanationPlacement == _ExplanationPlacement.bottom;

            return AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final dx = sin(_shakeController.value * pi * 10) * 8;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _state == AnswerState.correct
                          ? const Color(0xFFDFF7E6)
                          : _state == AnswerState.wrong
                              ? const Color(0xFFFFEAEA)
                              : const Color(0xFFF7FCF8),
                      const Color(0xFFFFFFFF),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2EDE5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFE6F8EC),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.auto_stories_rounded,
                                  color: Color(0xFF21984A), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0, 1).toDouble(),
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFE7EEE9),
                                  valueColor: const AlwaysStoppedAnimation(
                                      AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${_blockIndex + 1}/${blocks.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF315743)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        block.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF213126),
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Focus mode is on. Complete this step to keep your streak alive.',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5D6A78)),
                      ),
                      const SizedBox(height: 10),
                      if (topExplanation)
                        _ExplanationCard(text: block.baseExplanation),
                      if (topExplanation) const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _BlockRenderer(
                            block: block,
                            selectedChoice: _selected,
                            orderedTokens: _orderedTokens,
                            answerState: _state,
                            speechReady: _speechReady,
                            isListening: _isListening,
                            isSpeaking: _isSpeaking,
                            onSelectChoice: (value) =>
                                setState(() => _selected = value),
                            onReorderTokens: (newTokens) =>
                                setState(() => _orderedTokens = newTokens),
                            onInlineExplain: (contextText) => _openExplainSheet(
                              lesson: lesson,
                              block: block,
                              blockIndex: _blockIndex,
                              inlineContext: contextText,
                            ),
                            onPressSpeaker: () => _runDialogueSpeechAssist(block),
                          ),
                        ),
                      ),
                      if (middleExplanation) const SizedBox(height: 10),
                      if (middleExplanation)
                        _ExplanationCard(text: block.baseExplanation),
                      if (_isChecked)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _state == AnswerState.correct
                                ? const Color(0xFFE7FBEA)
                                : const Color(0xFFFFEFEF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _state == AnswerState.correct
                                  ? const Color(0xFFB8E8C5)
                                  : const Color(0xFFF5C8C8),
                            ),
                          ),
                          child: Text(
                            _state == AnswerState.correct
                                ? 'Correct. Nice job.'
                                : 'Not quite. Review and retry this block.',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _state == AnswerState.correct
                                  ? const Color(0xFF1D9B36)
                                  : const Color(0xFFD13F3F),
                            ),
                          ),
                        ),
                      if (bottomExplanation) const SizedBox(height: 10),
                      if (bottomExplanation)
                        _ExplanationCard(text: block.baseExplanation),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _showHint(context, block.hint),
                            icon: const Icon(Icons.lightbulb_rounded,
                                color: Color(0xFF3E6FD0)),
                            label: const Text('Hint'),
                          ),
                          if (_isChecked && _state == AnswerState.wrong)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selected = null;
                                  if (block.type == _LessonBlockType.ordering) {
                                    _orderedTokens = <String>[];
                                  }
                                  _state = AnswerState.normal;
                                  _isChecked = false;
                                });
                              },
                              child: const Text('Retry'),
                            ),
                          const Spacer(),
                          SizedBox(
                            width: 172,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                if (!_isChecked) {
                                  await _checkCurrentBlock(block);
                                  return;
                                }

                                if (_state == AnswerState.wrong &&
                                    block.hasQuestion) {
                                  setState(() {
                                    _selected = null;
                                    if (block.type ==
                                        _LessonBlockType.ordering) {
                                      _orderedTokens = <String>[];
                                    }
                                    _state = AnswerState.normal;
                                    _isChecked = false;
                                  });
                                  return;
                                }

                                if (_blockIndex < blocks.length - 1) {
                                  setState(() {
                                    _blockIndex += 1;
                                  });
                                  _resetForNextBlock();
                                  return;
                                }

                                await _completeLesson(blocks);
                              },
                              child: Text(!_isChecked
                                  ? 'Check'
                                  : (_blockIndex == blocks.length - 1
                                      ? 'Finish'
                                      : 'Continue')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tip: One lesson can contain multiple blocks (dialogue, sentence, quiz, ordering).',
                        style: TextStyle(
                            color: Color(0xFF6C7784),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1D8D8)),
              ),
              child: const Text(
                'Failed to load lesson. Please go back and try again.',
                style: TextStyle(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showHint(BuildContext context, String hint) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child:
              Text(hint, style: const TextStyle(fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}

enum _LessonBlockType { dialogue, sentence, ordering, translationMcq }

enum _ExplanationPlacement { top, middle, bottom }

class _LessonBlock {
  const _LessonBlock({
    required this.type,
    required this.title,
    required this.hint,
    required this.baseExplanation,
    required this.explanationPlacement,
    required this.answer,
    required this.choices,
    required this.dialogue,
    required this.orderingTokens,
    required this.hasQuestion,
  });

  final _LessonBlockType type;
  final String title;
  final String hint;
  final String baseExplanation;
  final _ExplanationPlacement explanationPlacement;
  final String answer;
  final List<String> choices;
  final List<({String speaker, String text, bool mine})> dialogue;
  final List<String> orderingTokens;
  final bool hasQuestion;
}

class _BlockRenderer extends StatelessWidget {
  const _BlockRenderer({
    required this.block,
    required this.selectedChoice,
    required this.orderedTokens,
    required this.answerState,
    required this.speechReady,
    required this.isListening,
    required this.isSpeaking,
    required this.onSelectChoice,
    required this.onReorderTokens,
    required this.onInlineExplain,
    required this.onPressSpeaker,
  });

  final _LessonBlock block;
  final String? selectedChoice;
  final List<String>? orderedTokens;
  final AnswerState answerState;
  final bool speechReady;
  final bool isListening;
  final bool isSpeaking;
  final void Function(String value) onSelectChoice;
  final void Function(List<String> newTokens) onReorderTokens;
  final Future<void> Function(String contextText) onInlineExplain;
  final Future<void> Function() onPressSpeaker;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case _LessonBlockType.dialogue:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFFFD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4EEE7)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFFE8F8ED),
                    child: Icon(Icons.record_voice_over_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tutor Camille',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        Text('Dialogue practice',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF637184),
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Speak',
                    onPressed: speechReady ? onPressSpeaker : null,
                    icon: isSpeaking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isListening
                                ? Icons.mic_rounded
                                : Icons.volume_up_rounded,
                            color: AppColors.primary,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...block.dialogue.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment:
                      line.mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: line.mine
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (!line.mine)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(0xFFE7F8EC),
                            child: Icon(Icons.school_rounded,
                                size: 15, color: AppColors.primary),
                          ),
                        ),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 270),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: line.mine
                              ? AppColors.primary
                              : const Color(0xFFFDFEFD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE3EEE6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.speaker,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: line.mine
                                    ? Colors.white70
                                    : AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              line.text,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: line.mine
                                    ? Colors.white
                                    : const Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                ActionChip(
                                  label: const Text('Explain'),
                                  onPressed: () => onInlineExplain(line.text),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Choose your reply',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            ...block.choices.map(
              (choice) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnswerButton(
                  text: choice,
                  state: selectedChoice == choice
                      ? answerState
                      : AnswerState.normal,
                  isSelected: selectedChoice == choice,
                  onTap: () => onSelectChoice(choice),
                ),
              ),
            ),
          ],
        );
      case _LessonBlockType.sentence:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF7FBF8)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4EEE7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Read and absorb the sentence pattern before continuing.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ActionChip(
                label: const Text('Explain sentence'),
                onPressed: () => onInlineExplain(block.baseExplanation),
              ),
            ],
          ),
        );
      case _LessonBlockType.ordering:
        final selectedTokens = orderedTokens ?? const <String>[];

        int countInList(List<String> list, String token) {
          return list.where((value) => value == token).length;
        }

        final bankTokens = block.orderingTokens
            .where((token) =>
                countInList(selectedTokens, token) <
                countInList(block.orderingTokens, token))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tap words to build the sentence',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 66),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFDFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD9E7DF)),
              ),
              child: selectedTokens.isEmpty
                  ? const Text(
                      'Selected words appear here',
                      style: TextStyle(
                          color: Color(0xFF7A8896),
                          fontWeight: FontWeight.w700),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < selectedTokens.length; i++)
                          InputChip(
                            label: Text(selectedTokens[i]),
                            selected: true,
                            selectedColor: const Color(0xFFDFF5E5),
                            side: const BorderSide(color: Color(0xFFBEE6CA)),
                            onPressed: () {
                              final updated = [...selectedTokens]..removeAt(i);
                              onReorderTokens(updated);
                            },
                            deleteIcon:
                                const Icon(Icons.close_rounded, size: 16),
                            onDeleted: () {
                              final updated = [...selectedTokens]..removeAt(i);
                              onReorderTokens(updated);
                            },
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            const Text('Word bank',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF5E6D7C))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final token in bankTokens)
                  ActionChip(
                    label: Text(token,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    side: const BorderSide(color: Color(0xFFD5E6DA)),
                    backgroundColor: Colors.white,
                    onPressed: () =>
                        onReorderTokens([...selectedTokens, token]),
                  ),
              ],
            ),
            if (selectedTokens.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => onReorderTokens(const []),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Clear selection'),
              ),
            ],
          ],
        );
      case _LessonBlockType.translationMcq:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...block.choices.map(
              (choice) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AnswerButton(
                  text: choice,
                  state: selectedChoice == choice
                      ? answerState
                      : AnswerState.normal,
                  isSelected: selectedChoice == choice,
                  onTap: () => onSelectChoice(choice),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFE9F4FF), Color(0xFFF4FAFF)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCEE1FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.translate_rounded, size: 17, color: Color(0xFF2A6ECF)),
              SizedBox(width: 6),
              Text('Base Language Explanation',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: Color(0xFF2A6ECF))),
            ],
          ),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E476C),
                  height: 1.25)),
        ],
      ),
    );
  }
}

class _LessonExplainData {
  const _LessonExplainData({
    required this.simple,
    required this.examples,
    required this.rules,
  });

  final String simple;
  final List<String> examples;
  final List<String> rules;

  factory _LessonExplainData.fromReply({
    required String reply,
    required String baseLanguage,
  }) {
    String section(String marker, String next) {
      final start = reply.indexOf(marker);
      if (start == -1) return '';
      final from = start + marker.length;
      final end = next.isEmpty ? reply.length : reply.indexOf(next, from);
      if (end == -1) return reply.substring(from).trim();
      return reply.substring(from, end).trim();
    }

    final simple = section('SIMPLE:', 'EXAMPLES:');
    final examplesRaw = section('EXAMPLES:', 'RULES:');
    final rulesRaw = section('RULES:', '');

    final examples = examplesRaw
        .split('\n')
        .map((e) => e.replaceFirst('-', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final rules = rulesRaw
        .split('\n')
        .map((e) => e.replaceFirst('-', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (simple.isEmpty && examples.isEmpty && rules.isEmpty) {
      return _LessonExplainData(
        simple: reply.trim(),
        examples: const [],
        rules: [
          'Explanation provided in $baseLanguage',
        ],
      );
    }

    return _LessonExplainData(
      simple: simple.isEmpty ? reply.trim() : simple,
      examples: examples,
      rules: rules,
    );
  }

  factory _LessonExplainData.fromApi({
    required Map<String, dynamic> data,
    required String fallbackLanguage,
  }) {
    final simple = (data['simple'] as String?)?.trim() ?? '';
    final examplesRaw = data['examples'];
    final rulesRaw = data['rules'];

    final examples = examplesRaw is List
        ? examplesRaw
            .map((item) => item.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final rules = rulesRaw is List
        ? rulesRaw
            .map((item) => item.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    if (simple.isEmpty && examples.isEmpty && rules.isEmpty) {
      return const _LessonExplainData(
        simple: 'Explanation is not available yet. Please try again.',
        examples: [],
        rules: [],
      );
    }

    return _LessonExplainData(
      simple: simple.isEmpty
          ? 'Explanation provided in $fallbackLanguage.'
          : simple,
      examples: examples,
      rules: rules,
    );
  }
}

List<_LessonBlock> _buildBlocksFromContent(Map<String, dynamic> content) {
  final blocksRaw = content['blocks'];
  if (blocksRaw is List && blocksRaw.isNotEmpty) {
    return blocksRaw.whereType<Map<String, dynamic>>().map((json) {
      final typeRaw = (json['type'] ?? 'translation_mcq').toString();
      final type = switch (typeRaw) {
        'dialogue' => _LessonBlockType.dialogue,
        'sentence' => _LessonBlockType.sentence,
        'ordering' => _LessonBlockType.ordering,
        'translation_mcq' => _LessonBlockType.translationMcq,
        _ => _LessonBlockType.translationMcq,
      };

      final dialogueRaw = (json['dialogue'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      return _LessonBlock(
        type: type,
        title: (json['title'] ?? 'Practice Block').toString(),
        hint: (json['hint'] ?? 'Focus on meaning and structure.').toString(),
        baseExplanation: (json['base_explanation'] ??
                'Explanation will appear here in native language.')
            .toString(),
        explanationPlacement: switch (
            (json['explanation_placement'] ?? 'middle').toString()) {
          'top' => _ExplanationPlacement.top,
          'bottom' => _ExplanationPlacement.bottom,
          _ => _ExplanationPlacement.middle,
        },
        answer: (json['answer'] ?? '').toString(),
        choices: ((json['choices'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        dialogue: dialogueRaw
            .map(
              (d) => (
                speaker: (d['speaker'] ?? 'Tutor').toString(),
                text: (d['text'] ?? '').toString(),
                mine: (d['mine'] as bool?) ?? false,
              ),
            )
            .toList(),
        orderingTokens: ((json['tokens'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        hasQuestion: (json['has_question'] as bool?) ?? true,
      );
    }).toList();
  }

  // Fallback while backend block payload is in progress.
  return const [
    _LessonBlock(
      type: _LessonBlockType.dialogue,
      title: 'Dialogue: Introductions',
      hint: 'Use "Je m\'appelle ..." to introduce your name.',
      baseExplanation:
          'Amharic explanation: This dialogue teaches basic self-introduction and polite responses.',
      explanationPlacement: _ExplanationPlacement.top,
      answer: 'Je m\'appelle Hana.',
      choices: ['Je m\'appelle Hana.', 'Je suis fatigue.', 'Au revoir.'],
      dialogue: [
        (
          speaker: 'Tutor',
          text: 'Salut! Comment tu t\'appelles ?',
          mine: false
        ),
        (speaker: 'You', text: '...', mine: true),
      ],
      orderingTokens: [],
      hasQuestion: true,
    ),
    _LessonBlock(
      type: _LessonBlockType.sentence,
      title: 'Simple Sentence',
      hint: 'Read this and continue.',
      baseExplanation:
          'Amharic explanation: "Je vais bien" means "I am doing well" and is a common daily phrase.',
      explanationPlacement: _ExplanationPlacement.middle,
      answer: '',
      choices: [],
      dialogue: [],
      orderingTokens: [],
      hasQuestion: false,
    ),
    _LessonBlock(
      type: _LessonBlockType.ordering,
      title: 'Ordering Quiz',
      hint: 'Arrange words to match the target meaning.',
      baseExplanation:
          'Amharic explanation: Build the sentence in the same order as natural French speech.',
      explanationPlacement: _ExplanationPlacement.bottom,
      answer: 'Je vais bien merci',
      choices: [],
      dialogue: [],
      orderingTokens: ['merci', 'vais', 'Je', 'bien'],
      hasQuestion: true,
    ),
    _LessonBlock(
      type: _LessonBlockType.translationMcq,
      title: 'How do we say "How are you?"',
      hint: 'Pick the standard everyday phrase.',
      baseExplanation:
          'Amharic explanation: "Comment ca va?" is the typical informal way to ask "How are you?".',
      explanationPlacement: _ExplanationPlacement.middle,
      answer: 'Comment ca va ?',
      choices: ['Comment ca va ?', 'Ou habites-tu ?', 'Je vais bien.'],
      dialogue: [],
      orderingTokens: [],
      hasQuestion: true,
    ),
  ];
}
