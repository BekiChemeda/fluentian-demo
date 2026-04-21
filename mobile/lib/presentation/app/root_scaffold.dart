import 'package:flutter/material.dart';

import '../features/communication/communication_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/profile/profile_screen.dart';
import '../roadmap/roadmap_screen.dart';
import '../features/more/more_screen.dart';

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  final _screens = const [
    RoadmapScreen(),
    DashboardScreen(),
    CommunicationScreen(),
    ProfileScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (idx) => setState(() => _index = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.school_rounded), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.forum_rounded), label: 'Communication'),
          NavigationDestination(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }
}
