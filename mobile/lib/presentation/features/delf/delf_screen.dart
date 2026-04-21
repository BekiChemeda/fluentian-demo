import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/delf_model.dart';
import '../../app/providers.dart';

class DelfScreen extends ConsumerStatefulWidget {
  const DelfScreen({super.key});

  @override
  ConsumerState<DelfScreen> createState() => _DelfScreenState();
}

class _DelfScreenState extends ConsumerState<DelfScreen> {
  bool _loading = true;
  String? _error;
  List<DelfTestSummary> _tests = const [];
  DelfTestDetail? _activeTest;
  final Map<String, String> _answers = <String, String>{};
  DelfSubmitResult? _result;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _activeTest = null;
      _answers.clear();
    });

    try {
      final tests = await ref.read(delfRepositoryProvider).listTests();
      setState(() {
        _tests = tests;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _startTest(DelfTestSummary summary) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _activeTest = null;
      _answers.clear();
    });
    try {
      final detail = await ref.read(delfRepositoryProvider).getTest(summary.id);
      setState(() {
        _activeTest = detail;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final test = _activeTest;
    if (test == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(delfRepositoryProvider).submit(test.id, _answers);
      setState(() {
        _result = result;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('DELF Practice')),
        body: Center(child: Text(_error!)),
      );
    }

    final activeTest = _activeTest;
    if (activeTest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('DELF Practice')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Mock Tests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ..._tests.map(
              (test) => Card(
                child: ListTile(
                  title: Text('${test.title} (${test.level})'),
                  subtitle: Text('${test.description}\n${test.questionCount} questions • pass ${test.passingScore}%'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => _startTest(test),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(activeTest.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _loadTests,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Level ${activeTest.level} • pass ${activeTest.passingScore}%'),
          const SizedBox(height: 8),
          Text(activeTest.description),
          const SizedBox(height: 16),
          ...activeTest.questions.map((question) {
            final selected = _answers[question.id];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.prompt, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...question.choices.map(
                      (choice) => RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(choice),
                        value: choice,
                        groupValue: selected,
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _answers[question.id] = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Submit test'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text('Score: ${_result!.score}%'),
                subtitle: Text(
                  '${_result!.correctCount}/${_result!.totalQuestions} correct • ${_result!.passed ? 'PASSED' : 'NOT PASSED'}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
