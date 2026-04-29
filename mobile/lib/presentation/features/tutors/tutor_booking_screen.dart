import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/platform_models.dart';
import '../../app/providers.dart';
import '../../widgets/app_state_widgets.dart';

class TutorBookingScreen extends ConsumerWidget {
  const TutorBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tutors = ref.watch(tutorsProvider);
    final bookings = ref.watch(bookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tutors')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tutorsProvider);
          ref.invalidate(bookingsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            bookings.maybeWhen(
              data: (items) => _BookingStrip(bookings: items),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            tutors.when(
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.school_outlined,
                    title: 'No tutors available',
                    message:
                        'Ask an admin to create tutor profiles in the backend.',
                  );
                }
                return Column(
                  children: [
                    for (final tutor in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TutorCard(tutor: tutor),
                      ),
                  ],
                );
              },
              loading: () => const AppLoadingState(message: 'Loading tutors'),
              error: (_, __) => AppErrorState(
                title: 'Tutors unavailable',
                message: 'Tutor scheduling may not be seeded yet.',
                onRetry: () => ref.invalidate(tutorsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingStrip extends StatelessWidget {
  const _BookingStrip({required this.bookings});

  final List<BookingModel> bookings;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const SizedBox.shrink();
    }

    return FluentianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your bookings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final booking in bookings.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${booking.topic.isEmpty ? 'Tutor session' : booking.topic} · '
                '${booking.status} · ${booking.startsAt.toLocal()}',
              ),
            ),
        ],
      ),
    );
  }
}

class _TutorCard extends ConsumerStatefulWidget {
  const _TutorCard({required this.tutor});

  final TutorProfileModel tutor;

  @override
  ConsumerState<_TutorCard> createState() => _TutorCardState();
}

class _TutorCardState extends ConsumerState<_TutorCard> {
  final _topicController = TextEditingController();
  DateTime _startsAt = DateTime.now().add(const Duration(days: 1));
  bool _booking = false;
  String? _error;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _book() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'Add a short session topic.');
      return;
    }
    setState(() {
      _booking = true;
      _error = null;
    });
    try {
      await ref.read(platformRepositoryProvider).createBooking(
            tutorUserId: widget.tutor.userId,
            startsAt: _startsAt,
            endsAt: _startsAt.add(const Duration(minutes: 30)),
            topic: topic,
          );
      ref.invalidate(bookingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking requested.')),
        );
      }
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.statusCode == 409
            ? 'That tutor is already booked for this time.'
            : 'Could not create booking.';
      });
    } catch (_) {
      setState(() => _error = 'Could not create booking.');
    } finally {
      if (mounted) {
        setState(() => _booking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FluentianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.secondary.withValues(alpha: 0.16),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.tutor.headline,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(
                      '${widget.tutor.languages} · '
                      '${widget.tutor.hourlyRate.toStringAsFixed(0)} ${widget.tutor.currency}/hr',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.tutor.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(widget.tutor.bio),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Session topic',
              hintText: 'Example: A1 speaking practice',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Starts: ${_startsAt.toLocal()}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Move later',
                onPressed: () {
                  setState(() {
                    _startsAt = _startsAt.add(const Duration(hours: 1));
                  });
                },
                icon: const Icon(Icons.schedule_rounded),
              ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _booking ? null : _book,
              icon: const Icon(Icons.event_available_rounded),
              label: Text(_booking ? 'Booking...' : 'Book 30 min'),
            ),
          ),
        ],
      ),
    );
  }
}
