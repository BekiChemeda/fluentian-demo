import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _period = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final players = [
      ('Hana', 1240, true, 'promote'),
      ('Miki', 1180, false, 'promote'),
      ('Sam', 1050, false, 'stay'),
      ('Liya', 980, false, 'stay'),
      ('Kokeb', 860, false, 'relegate'),
    ];
    final filtered = players
        .where((p) => p.$1.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF8FF), Color(0xFFFFF8EE)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1BAA46),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _period == 0 ? 'Bronze League - Weekly Sprint' : (_period == 1 ? 'Monthly League' : 'Friends Ranking'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Expanded(child: Text('Top 2 promote', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A9D3A)))),
                  Expanded(child: Text('Middle stay', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800))),
                  Expanded(child: Text('Bottom 1 relegates', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFC84343)))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Week')),
                ButtonSegment(value: 1, label: Text('Month')),
                ButtonSegment(value: 2, label: Text('Friends')),
              ],
              selected: {_period},
              onSelectionChanged: (value) => setState(() => _period = value.first),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search player',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No player found for this search.'),
                ),
              ),
            ...filtered.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final p = entry.value;
              final movement = p.$4;
              final moveColor = movement == 'promote'
                  ? const Color(0xFF1A9D3A)
                  : (movement == 'relegate' ? const Color(0xFFC84343) : const Color(0xFF6A6A6A));
              final moveIcon = movement == 'promote'
                  ? Icons.north_rounded
                  : (movement == 'relegate' ? Icons.south_rounded : Icons.drag_handle_rounded);
              final moveText = movement == 'promote' ? 'Promote' : (movement == 'relegate' ? 'Relegate' : 'Stay');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.$3 ? const Color(0xFFEAFBEF) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.$3 ? const Color(0xFF7BD18E) : const Color(0xFFE8E8E8)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: rank == 1 ? Colors.amber : const Color(0xFFDAF2E0),
                      child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${p.$2} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(moveIcon, size: 16, color: moveColor),
                            const SizedBox(width: 2),
                            Text(moveText, style: TextStyle(fontWeight: FontWeight.w800, color: moveColor)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
