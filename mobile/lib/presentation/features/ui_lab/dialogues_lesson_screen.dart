import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class DialoguesLessonScreen extends StatefulWidget {
  const DialoguesLessonScreen({super.key});

  @override
  State<DialoguesLessonScreen> createState() => _DialoguesLessonScreenState();
}

class _DialoguesLessonScreenState extends State<DialoguesLessonScreen> {
  int _step = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _checked = false;

  static const _steps = [
    (
      'Tutor asks: "Comment ca va ?"',
      ['Je vais bien, merci.', 'Bonsoir et au revoir.', 'Je suis fatigue.'],
      0,
      'You should answer how you are doing.',
      'In Amharic: This sentence means "How are you?". A polite answer is "I am fine, thank you."',
    ),
    (
      'Tutor asks: "Comment tu t\'appelles ?"',
      ['Je m\'appelle Hana.', 'Je suis fatigue.', 'Au revoir.'],
      0,
      'Use "Je m\'appelle ..." for introducing your name.',
      'In Amharic: This asks for your name. Start with "Je m\'appelle..." to introduce yourself naturally.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const bubbles = [
      ('Tutor', 'Salut! Comment tu t\'appelles ?', false),
      ('You', 'Je m\'appelle Hana.', true),
      ('Tutor', 'Tres bien. Comment ca va ?', false),
      ('You', 'Ca va bien, merci.', true),
    ];

    final prompt = _steps[_step];
    final choices = prompt.$2;
    final correct = prompt.$3;
    final isCorrect = _checked && _selectedIndex == correct;
    final progress = (_step + (_checked ? 1 : 0)) / _steps.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dialogue Lesson')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FFF3), Color(0xFFFFF8EE)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: progress.clamp(0, 1).toDouble(), minHeight: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4EEE7)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE8F8ED),
                      child: Icon(Icons.person_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tutor Camille', style: TextStyle(fontWeight: FontWeight.w900)),
                          Text('Listen and respond naturally', style: TextStyle(fontSize: 12, color: Color(0xFF637184), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Speak prompt',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Speaking prompt... (TTS placeholder)')),
                        );
                      },
                      icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: bubbles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final b = bubbles[i];
                  final mine = b.$3;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!mine)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFE7F8EC),
                              child: Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
                            ),
                          ),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    b.$1,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: mine ? Colors.white70 : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.volume_up_rounded,
                                    size: 15,
                                    color: mine ? Colors.white70 : AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b.$2,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: mine ? Colors.white : const Color(0xFF1E1E1E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (mine)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFFDDF6E5),
                              child: Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose your reply', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(prompt.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  _ExplanationBlock(text: prompt.$5),
                  const SizedBox(height: 10),
                  ...choices.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ReplyChoice(
                            text: entry.value,
                            selected: _selectedIndex == entry.key,
                            disabled: _checked,
                            onTap: () => setState(() => _selectedIndex = entry.key),
                          ),
                        ),
                      ),
                  if (_checked)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 2, bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCorrect ? const Color(0xFFE7FBEA) : const Color(0xFFFFEFEF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCorrect ? 'Great. Natural and polite response.' : 'Not the best response here. Try again.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isCorrect ? const Color(0xFF1D9B36) : const Color(0xFFD13F3F),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _showHint(context, prompt.$4),
                        icon: const Icon(Icons.lightbulb_rounded),
                        label: const Text('Hint'),
                      ),
                      if (_checked && !isCorrect)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedIndex = null;
                              _checked = false;
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: 136,
                        child: ElevatedButton(
                          onPressed: _selectedIndex == null
                              ? null
                              : () {
                                  if (!_checked) {
                                    setState(() => _checked = true);
                                    if (_selectedIndex == correct) {
                                      setState(() => _score += 1);
                                    }
                                    return;
                                  }

                                  if (!isCorrect) {
                                    setState(() {
                                      _selectedIndex = null;
                                      _checked = false;
                                    });
                                    return;
                                  }

                                  if (_step < _steps.length - 1) {
                                    setState(() {
                                      _step += 1;
                                      _selectedIndex = null;
                                      _checked = false;
                                    });
                                    return;
                                  }
                                  _showComplete(context, _score, _steps.length);
                                },
                          child: Text(
                            !_checked
                                ? 'Check'
                                : (isCorrect ? 'Continue' : 'Try Again'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
          padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Text(
            hint,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  void _showComplete(BuildContext context, int score, int total) {
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
              const Text('Dialogue Completed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Score: $score / $total'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(this.context).pop();
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExplanationBlock extends StatelessWidget {
  const _ExplanationBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9F3FF), Color(0xFFF4FAFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.translate_rounded, size: 18, color: Color(0xFF2A6ECF)),
              SizedBox(width: 6),
              Text('Base Language Explanation', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2A6ECF))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF2E476C),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyChoice extends StatelessWidget {
  const _ReplyChoice({
    required this.text,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6FAEB) : const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF3CB758) : const Color(0xFFD5E7D9), width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
