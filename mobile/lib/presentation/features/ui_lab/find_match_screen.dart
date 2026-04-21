import 'package:flutter/material.dart';

class FindMatchScreen extends StatefulWidget {
  const FindMatchScreen({super.key});

  @override
  State<FindMatchScreen> createState() => _FindMatchScreenState();
}

class _FindMatchScreenState extends State<FindMatchScreen> {
  bool _loading = false;
  int? _selectedIndex;
  int _loadingStep = 0;
  int? _matchedIndex;
  String _mode = 'Text';
  final _filters = <String>{'A1', 'Voice Chat'};

  final _matches = <_MatchData>[
    const _MatchData(name: 'Sara', level: 'A1', streak: 14, xp: 1040),
    const _MatchData(name: 'Noah', level: 'A1', streak: 9, xp: 960),
    const _MatchData(name: 'Dina', level: 'A1', streak: 21, xp: 1120),
  ];

  Future<void> _find() async {
    setState(() {
      _loading = true;
      _selectedIndex = null;
      _matchedIndex = null;
      _loadingStep = 0;
    });
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _loadingStep = i + 1);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _matchedIndex = 0;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Match')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFEFFAF0), Color(0xFFFFF8EE)]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Practice Partner', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Match by level, goals, and active streak.'),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Text', label: Text('Text Chat')),
                  ButtonSegment(value: 'Audio', label: Text('Audio Chat')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              const SizedBox(height: 16),
              _FilterPillRow(
                selected: _filters,
                onToggle: (filter) {
                  setState(() {
                    if (_filters.contains(filter)) {
                      _filters.remove(filter);
                    } else {
                      _filters.add(filter);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? _MatchLoading(step: _loadingStep)
                    : ListView.builder(
                        itemCount: _matches.length,
                        itemBuilder: (context, index) {
                          final item = _matches[index];
                          return _MatchCard(
                            data: item,
                            selected: _selectedIndex == index,
                            onTap: () => setState(() => _selectedIndex = index),
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(onPressed: _find, child: const Text('Find Best Match')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _selectedIndex == null
                          ? null
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Starting $_mode chat with ${_matches[_selectedIndex!].name}...')),
                              );
                            },
                      child: Text('Start $_mode'),
                    ),
                  ),
                ],
              ),
              if (_matchedIndex != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAFBEF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Matched with ${_matches[_matchedIndex!].name} from your friends-level pool.',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A8E35)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchLoading extends StatelessWidget {
  const _MatchLoading({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final lines = [
      'Scanning your friends list...',
      'Checking A1 fluency and streak compatibility...',
      'Choosing best partner for text/audio practice...',
    ];

    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 130,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WorldMapPainter(),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(-0.72, -0.2),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF3BB85A),
                      child: Icon(Icons.person_rounded, color: Colors.white),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(0.72, 0.2),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF4F8BFF),
                      child: Icon(Icons.person_rounded, color: Colors.white),
                    ),
                  ),
                  const Align(
                    child: Icon(Icons.sync_alt_rounded, color: Color(0xFF2D7BFF), size: 34),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(lines[step.clamp(0, 2)], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const SizedBox(
              width: 180,
              child: LinearProgressIndicator(minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sea = Paint()..color = const Color(0xFFEAF4FF);
    final land = Paint()..color = const Color(0xFFDFF3E3);
    final route = Paint()
      ..color = const Color(0xFF7B9CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(rect, sea);

    canvas.drawOval(Rect.fromLTWH(size.width * 0.1, size.height * 0.22, size.width * 0.24, size.height * 0.22), land);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.28, size.height * 0.5, size.width * 0.2, size.height * 0.2), land);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.58, size.height * 0.28, size.width * 0.28, size.height * 0.26), land);

    final p = Path()
      ..moveTo(size.width * 0.18, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.1, size.width * 0.8, size.height * 0.6);
    canvas.drawPath(p, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FilterPillRow extends StatelessWidget {
  const _FilterPillRow({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String filter) onToggle;

  @override
  Widget build(BuildContext context) {
    const options = ['A1', 'Voice Chat', 'Daily XP 20+', 'Evening'];
    return Wrap(
      spacing: 8,
      children: options
          .map(
            (f) => _Pill(
              f,
              active: selected.contains(f),
              onTap: () => onToggle(f),
            ),
          )
          .toList(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.active, required this.onTap});

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3DBA59) : const Color(0xFFE5F7EA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : const Color(0xFF134B22)),
        ),
      ),
    );
  }
}

class _MatchData {
  const _MatchData({required this.name, required this.level, required this.streak, required this.xp});

  final String name;
  final String level;
  final int streak;
  final int xp;
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.data, required this.selected, required this.onTap});

  final _MatchData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? const Color(0xFF3DBA59) : Colors.transparent, width: 1.4),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
        title: Text(data.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('Level ${data.level} • ${data.streak} day streak'),
        trailing: Text('${data.xp} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
