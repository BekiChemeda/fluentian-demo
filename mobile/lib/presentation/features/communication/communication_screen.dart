import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../ui_lab/audio_call_screen.dart';
import 'communication_controller.dart';
import 'communication_state.dart';

class CommunicationScreen extends ConsumerStatefulWidget {
  const CommunicationScreen({super.key});

  @override
  ConsumerState<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends ConsumerState<CommunicationScreen> {
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communicationControllerProvider.notifier).bootstrap();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communicationControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                state.presenceLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: switch (state.phase) {
            CommunicationPhase.match => _MatchPane(
                state: state,
                onJoin: () => ref.read(communicationControllerProvider.notifier).joinQueue(),
                onLeave: () => ref.read(communicationControllerProvider.notifier).leaveQueue(),
                onModeChanged: (value) => ref.read(communicationControllerProvider.notifier).updateSelectedMode(value),
                onIntentChanged: (value) => ref.read(communicationControllerProvider.notifier).updateSelectedIntent(value),
                onLevelChanged: (value) => ref.read(communicationControllerProvider.notifier).updateSelectedLevel(value),
                onConsentChanged: (value) => ref.read(communicationControllerProvider.notifier).updateRecordingConsent(value),
              ),
            CommunicationPhase.session => _SessionPane(
                state: state,
                messageController: _messageController,
                onSend: () {
                  final text = _messageController.text.trim();
                  if (text.isEmpty) {
                    return;
                  }
                  ref.read(communicationControllerProvider.notifier).sendTextMessage(text);
                  _messageController.clear();
                },
                onEnd: () {
                  final partner = state.partner;
                  if (partner == null) {
                    return;
                  }
                  ref.read(communicationControllerProvider.notifier).endSession(endedBy: partner.id);
                },
                onRefresh: () => ref.read(communicationControllerProvider.notifier).refreshMessages(),
                onInviteCall: () => ref.read(communicationControllerProvider.notifier).inviteCall(),
                onToggleMute: () => ref.read(communicationControllerProvider.notifier).toggleMute(),
                onHangup: () => ref.read(communicationControllerProvider.notifier).hangupCall(),
              ),
            CommunicationPhase.postSession => _PostSessionPane(
                state: state,
                onReport: () => ref.read(communicationControllerProvider.notifier).reportCurrentPartner('other'),
                onBlock: () => ref.read(communicationControllerProvider.notifier).blockCurrentPartner('session_safety'),
                onRetry: () => ref.read(communicationControllerProvider.notifier).joinQueue(),
              ),
          },
        ),
      ),
    );
  }
}

class _MatchPane extends StatelessWidget {
  const _MatchPane({
    required this.state,
    required this.onJoin,
    required this.onLeave,
    required this.onModeChanged,
    required this.onIntentChanged,
    required this.onLevelChanged,
    required this.onConsentChanged,
  });

  final CommunicationState state;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onIntentChanged;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<bool> onConsentChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Realtime Match Lab',
          subtitle: 'Inspired by live pairing UIs with visible queue state and partner readiness signals.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RealtimePulsePanel(state: state),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Text session'),
                    selected: state.selectedMode == 'text',
                    onSelected: (_) => onModeChanged('text'),
                  ),
                  ChoiceChip(
                    label: const Text('Audio session'),
                    selected: state.selectedMode == 'audio',
                    onSelected: (_) => onModeChanged('audio'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: state.selectedIntent,
                decoration: const InputDecoration(labelText: 'Learning intent'),
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'exam', child: Text('Exam')),
                  DropdownMenuItem(value: 'travel', child: Text('Travel')),
                  DropdownMenuItem(value: 'business', child: Text('Business')),
                ],
                onChanged: (value) {
                  if (value != null) onIntentChanged(value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: state.selectedLevel,
                decoration: const InputDecoration(labelText: 'CEFR level'),
                items: const [
                  DropdownMenuItem(value: 'A1', child: Text('A1')),
                  DropdownMenuItem(value: 'A2', child: Text('A2')),
                  DropdownMenuItem(value: 'B1', child: Text('B1')),
                  DropdownMenuItem(value: 'B2', child: Text('B2')),
                  DropdownMenuItem(value: 'C1', child: Text('C1')),
                  DropdownMenuItem(value: 'C2', child: Text('C2')),
                ],
                onChanged: (value) {
                  if (value != null) onLevelChanged(value);
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Audio recording consent'),
                subtitle: const Text('Recording activates only when both users consent.'),
                value: state.recordingConsent,
                onChanged: onConsentChanged,
              ),
              const SizedBox(height: 8),
              Text(
                state.errorMessage ?? state.waitingPhrase,
                style: TextStyle(
                  color: state.errorMessage == null ? AppColors.textMuted : AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (state.queueStatus == CommunicationQueueStatus.searching) ...[
                LinearProgressIndicator(
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 10),
                const Text('Queue is live. Matching by mode, intent, level, and wait-time fairness.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onLeave,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel search'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Start realtime matching'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StatsCard(stats: state.stats),
      ],
    );
  }
}

class _RealtimePulsePanel extends StatelessWidget {
  const _RealtimePulsePanel({required this.state});

  final CommunicationState state;

  @override
  Widget build(BuildContext context) {
    final searching = state.queueStatus == CommunicationQueueStatus.searching;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F3FF), Color(0xFFF0FFF6)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: searching ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.14),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: const Icon(Icons.radar_rounded, color: AppColors.primary, size: 34),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  searching ? 'Searching in realtime' : 'Ready to search',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  searching
                      ? 'Looking for a compatible partner now.'
                      : 'Select filters and enter the queue.',
                  style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Status: ${state.connectionStatus.name}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionPane extends StatelessWidget {
  const _SessionPane({
    required this.state,
    required this.messageController,
    required this.onSend,
    required this.onEnd,
    required this.onRefresh,
    required this.onInviteCall,
    required this.onToggleMute,
    required this.onHangup,
  });

  final CommunicationState state;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final VoidCallback onEnd;
  final VoidCallback onRefresh;
  final VoidCallback onInviteCall;
  final VoidCallback onToggleMute;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    final partner = state.partner;
    return Column(
      children: [
        _SectionCard(
          title: 'Match found',
          subtitle: partner == null ? 'Loading partner details' : 'Partner: ${partner.email} • ${partner.language ?? 'FR'}',
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text((partner?.email ?? 'P').characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partner?.email ?? 'Partner', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('XP ${partner?.xp ?? 0} • Streak ${partner?.streak ?? 0}'),
                    Text('Session ${state.session?.sessionType ?? 'text'} • ${state.connectionStatus.name}'),
                    if ((state.session?.sessionType ?? 'text') == 'audio')
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AudioCallScreen(
                                isAi: false,
                                peerLabel: partner?.email ?? 'Partner',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.record_voice_over_rounded),
                        label: const Text('Open voice room'),
                      ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: onEnd,
                child: const Text('End session'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _ChatPanel(
            state: state,
            messages: state.messages,
            messageController: messageController,
            onSend: onSend,
            onRefresh: onRefresh,
            sessionType: state.session?.sessionType ?? 'text',
            onInviteCall: onInviteCall,
            onToggleMute: onToggleMute,
            onHangup: onHangup,
          ),
        ),
      ],
    );
  }
}

class _PostSessionPane extends StatelessWidget {
  const _PostSessionPane({
    required this.state,
    required this.onReport,
    required this.onBlock,
    required this.onRetry,
  });

  final CommunicationState state;
  final VoidCallback onReport;
  final VoidCallback onBlock;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Session complete',
          subtitle: 'Performance summary and feedback',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duration: ${session?.durationSeconds ?? 0} seconds', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Mode: ${session?.sessionType ?? 'text'}'),
              Text('Recording: ${session?.recordingUrl ?? 'disabled'}'),
              Text('Report flag: ${session?.reportFlag == true ? 'yes' : 'no'}'),
              const SizedBox(height: 14),
              const Text('How was the session?', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: const [
                  Chip(label: Text('Helpful')),
                  Chip(label: Text('Good pace')),
                  Chip(label: Text('Need more audio')),
                  Chip(label: Text('Need more grammar')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onBlock,
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Block'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Find another match'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _StatsCard(stats: state.stats),
      ],
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.state,
    required this.messages,
    required this.messageController,
    required this.onSend,
    required this.onRefresh,
    required this.sessionType,
    required this.onInviteCall,
    required this.onToggleMute,
    required this.onHangup,
  });

  final CommunicationState state;
  final List<CommunicationMessage> messages;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final VoidCallback onRefresh;
  final String sessionType;
  final VoidCallback onInviteCall;
  final VoidCallback onToggleMute;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: sessionType == 'audio' ? 'Live call' : 'Text chat',
      subtitle: sessionType == 'audio'
          ? 'Signaling active. Use invite/mute/hangup controls while media transport negotiates.'
          : 'Text conversation is routed through the session chat endpoints.',
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Row(
              children: [
                Text('Connection', style: Theme.of(context).textTheme.titleSmall),
                if (sessionType == 'audio')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      state.callSignalStatus,
                      style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                    ),
                  ),
                const Spacer(),
                IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            if (sessionType == 'audio')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onInviteCall,
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Invite'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onToggleMute,
                    icon: Icon(state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
                    label: Text(state.isMuted ? 'Unmute' : 'Mute'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onHangup,
                    icon: const Icon(Icons.call_end_rounded),
                    label: const Text('Hang up'),
                  ),
                ],
              ),
            if (sessionType == 'audio') const SizedBox(height: 8),
            const SizedBox(height: 8),
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return Align(
                          alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: message.isMe ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message.author, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(message.body),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(hintText: 'Write in French...'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: onSend, child: const Text('Send')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final CommunicationStats? stats;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Analytics',
      subtitle: 'User progress and session intelligence',
      child: stats == null
          ? const Text('Stats are loading...')
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(label: 'Today', value: '${stats!.today}s'),
                _Metric(label: 'Yesterday', value: '${stats!.yesterday}s'),
                _Metric(label: '7 days', value: '${stats!.weekly}s'),
                _Metric(label: 'Sessions', value: '${stats!.totalSessions}'),
                _Metric(label: 'Avg duration', value: stats!.averageSessionDuration.toStringAsFixed(1)),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 30, offset: Offset(0, 12), color: Color(0x14000000))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
