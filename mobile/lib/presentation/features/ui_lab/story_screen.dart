import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  int _step = 0;
  int? _selected;

  static const _steps = [
    (
      'Amelie entre dans le cafe et dit: "Bonjour! Un cafe, s\'il vous plait."\n\nWhat does she order?',
      ['She orders coffee.', 'She says goodbye.', 'She asks for water only.'],
      0,
    ),
    (
      'Le serveur repond: "Bien sur." Amelie veut aussi un dessert.\n\nWhat should she say?',
      ['Je voudrais un gateau.', 'Je vais a l\'ecole.', 'Je suis fatigue.'],
      0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final progress = (_step + 1) / _steps.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Story Mode')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFEFF8FF), Color(0xFFFFF8EE)]),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Cafe de Paris', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Read, listen, and choose what the character should say next.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            const SizedBox(height: 14),
            Container(
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              ),
              child: const Center(
                child: Icon(Icons.auto_stories_rounded, size: 76, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  step.$1,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...step.$2.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StoryOption(
                      text: entry.value,
                      selected: _selected == entry.key,
                      onTap: () => setState(() => _selected = entry.key),
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () {
                      final correct = _selected == step.$3;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(correct ? 'Nice choice!' : 'Not ideal for this context.')),
                      );
                      if (_step < _steps.length - 1) {
                        setState(() {
                          _step += 1;
                          _selected = null;
                        });
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
              child: Text(_step < _steps.length - 1 ? 'Continue Story' : 'Finish Story'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryOption extends StatelessWidget {
  const _StoryOption({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F4FA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE3E6E8), width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
