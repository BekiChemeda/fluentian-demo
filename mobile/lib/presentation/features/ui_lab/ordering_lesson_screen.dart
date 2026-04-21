import 'package:flutter/material.dart';
import 'dart:math';

class OrderingLessonScreen extends StatefulWidget {
  const OrderingLessonScreen({super.key});

  @override
  State<OrderingLessonScreen> createState() => _OrderingLessonScreenState();
}

class _OrderingLessonScreenState extends State<OrderingLessonScreen> {
  final List<String> _target = const ['Je', 'vais', 'bien'];
  final List<String> _wordBank = [];
  final List<String> _answer = [];
  String? _feedback;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    _reset(notify: false);
  }

  void _reset({bool notify = true}) {
    void apply() {
      _answer.clear();
      _wordBank
        ..clear()
        ..addAll(_target)
        ..shuffle(Random());
      _feedback = null;
      _correct = false;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _shuffle() {
    setState(() {
      _wordBank.shuffle(Random());
      _feedback = null;
      _correct = false;
    });
  }

  void _check() {
    final ok = _answer.join(' ') == _target.join(' ');
    setState(() {
      _correct = ok;
      _feedback = ok
          ? 'Perfect order. Great sentence flow.'
          : 'Almost. Try: Je vais bien';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ordering Lesson')),
      body: Container(
        decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFFEFFBF2), Color(0xFFFFF8EE)]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Arrange the words',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Form: "I am good" in French',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child:
                    const LinearProgressIndicator(value: 0.55, minHeight: 10),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _answer.isEmpty
                    ? const Text(
                        'Tap words below to build your answer',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.black54),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _answer
                            .asMap()
                            .entries
                            .map(
                              (entry) => ActionChip(
                                onPressed: () {
                                  setState(() {
                                    _wordBank.add(entry.value);
                                    _answer.removeAt(entry.key);
                                    _feedback = null;
                                    _correct = false;
                                  });
                                },
                                label: Text(entry.value,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                avatar:
                                    const Icon(Icons.close_rounded, size: 16),
                                backgroundColor: const Color(0xFFE6F8EA),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 14),
              if (_feedback != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _correct
                        ? const Color(0xFFEAFBEF)
                        : const Color(0xFFFFF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _feedback!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _correct
                          ? const Color(0xFF238F3B)
                          : const Color(0xFFC84646),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _wordBank
                        .asMap()
                        .entries
                        .map(
                          (entry) => ChoiceChip(
                            selected: false,
                            onSelected: (_) {
                              setState(() {
                                _answer.add(entry.value);
                                _wordBank.removeAt(entry.key);
                                _feedback = null;
                                _correct = false;
                              });
                            },
                            label: Text(entry.value,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            backgroundColor: const Color(0xFFF4F5F7),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shuffle,
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffle'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _answer.length == _target.length ? _check : null,
                child: Text(_correct ? 'Continue' : 'Check'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
