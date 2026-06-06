import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../api/api.dart';
import '../api/client.dart';
import '../models/suggestion.dart';
import '../models/summary.dart';
import '../theme.dart';
import '../widgets/ai_response_card.dart';
import '../main.dart';

// ── Message model ─────────────────────────────────────────────────────────────

sealed class ChatMessage {}

class UserMessage extends ChatMessage {
  final String text;
  UserMessage(this.text);
}

class AiMessage extends ChatMessage {
  final Suggestion suggestion;
  final String? minute; // e.g. "38'"
  AiMessage(this.suggestion, {this.minute});
}

class SystemMessage extends ChatMessage {
  final String text;
  SystemMessage(this.text);
}

class SummaryMessage extends ChatMessage {
  final Summary summary;
  SummaryMessage(this.summary);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LiveScreen extends StatefulWidget {
  final LiveScreenArgs args;

  const LiveScreen({super.key, required this.args});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _recorder = AudioRecorder();

  final List<ChatMessage> _messages = [];
  bool _sending = false;
  bool _recording = false;
  bool _changingRecordingState = false;
  bool _summaryDone = false;
  String? _recordingPath;

  int _matchMinute = 0;

  @override
  void initState() {
    super.initState();
    _messages.add(
      SystemMessage(
          'Match started. Tap the mic or type to log events and get suggestions.'),
    );
    // Tick the match clock every 60 seconds
    _startClock();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _startClock() {
    Future.delayed(const Duration(seconds: 60), () {
      if (!mounted) return;
      setState(() => _matchMinute++);
      _startClock();
    });
  }

  // ── Text note ────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() {
      _messages.add(UserMessage(text));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final resp = await api.sendNote(widget.args.matchId, text);
      setState(() {
        _messages.add(AiMessage(
          resp.suggestion,
          minute: "$_matchMinute'",
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(SystemMessage('Error: ${dioErrorMessage(e)}'));
      });
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // ── Voice note ────────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_changingRecordingState || _sending) return;

    _changingRecordingState = true;
    try {
      if (_recording) {
        await _stopRecording();
      } else {
        await _startRecording();
      }
    } catch (e) {
      if (mounted) {
        _showError('Recording error: $e');
      }
    } finally {
      _changingRecordingState = false;
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showError('Microphone permission denied.');
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    if (mounted) {
      setState(() => _recording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    final file = XFile(path);
    setState(() {
      _messages.add(UserMessage('🎙 Voice note…'));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final resp = await api.sendVoiceNote(widget.args.matchId, file);
      // Replace the placeholder with the actual transcription
      setState(() {
        _messages.removeLast(); // remove "Voice note..."
        _messages.add(UserMessage(resp.transcription));
        _messages.add(AiMessage(
          resp.suggestion,
          minute: "$_matchMinute'",
        ));
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(SystemMessage('Voice error: ${dioErrorMessage(e)}'));
      });
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // ── Quick actions ─────────────────────────────────────────────────────────

  void _quickAction(String text) {
    _textCtrl.text = text;
    _sendText();
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Future<void> _endMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End match?'),
        content: const Text('Generate the post-match summary now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End match'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final summary = await api.getSummary(widget.args.matchId);
      setState(() {
        _messages.add(SummaryMessage(summary));
        _summaryDone = true;
      });
    } catch (e) {
      _showError(dioErrorMessage(e));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live match'),
            Text(
              'vs ${widget.args.opponent} · $_matchMinute\'',
              style: kStyleSecondary,
            ),
          ],
        ),
        actions: [
          if (!_summaryDone)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kRedBg,
                    borderRadius: BorderRadius.circular(100),
                    border:
                        Border.all(color: kRedFg.withOpacity(0.3), width: 0.5),
                  ),
                  child: const Text(
                    'In progress',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: kRedFg,
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: Column(
        children: [
          // Chat log
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildMessage(_messages[i]),
            ),
          ),

          const Divider(height: 1),

          // Input area
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: switch (msg) {
        UserMessage(:final text) => _UserBubble(text: text),
        AiMessage(:final suggestion, :final minute) =>
          _AiBubble(suggestion: suggestion, minute: minute),
        SystemMessage(:final text) => _SystemBubble(text: text),
        SummaryMessage(:final summary) => _SummaryCard(summary: summary),
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick actions
          SizedBox(
            height: 36,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              scrollDirection: Axis.horizontal,
              children: [
                _QuickChip(
                  icon: Icons.sports_soccer_outlined,
                  label: 'Goal',
                  onTap: () => _quickAction('We scored a goal.'),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  icon: Icons.medical_services_outlined,
                  label: 'Injury',
                  onTap: () => _quickAction('Player has an injury.'),
                ),
                const SizedBox(width: 6),
                _QuickChip(
                  icon: Icons.assignment_outlined,
                  label: 'Summary',
                  onTap: _summaryDone ? null : _endMatch,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Text + mic row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mic button
                Semantics(
                  button: true,
                  label: _recording
                      ? 'Stop voice recording'
                      : 'Start voice recording',
                  child: GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _recording ? kRedFg : kBrand,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _recording ? Icons.stop : Icons.mic_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(
                      hintText: 'Type event or ask for advice…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: _sending ? null : _sendText,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _sending ? kBorderStrong : kBrand,
                      borderRadius: BorderRadius.circular(kRadiusInput),
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_outlined,
                            color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat bubble widgets ───────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kBrand,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRadiusCard),
            topRight: Radius.circular(kRadiusCard),
            bottomLeft: Radius.circular(kRadiusCard),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final Suggestion suggestion;
  final String? minute;

  const _AiBubble({required this.suggestion, this.minute});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (minute != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(minute!, style: kStyleLabel),
          ),
        AiResponseCard(suggestion: suggestion),
      ],
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final String text;
  const _SystemBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kSurfacePage,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: kBorderHairline, width: 0.5),
        ),
        child: Text(
          text,
          style: kStyleSecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Summary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 15, color: kTextBrand),
              SizedBox(width: 6),
              Text(
                'Post-match summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextBrand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Overview
          Text(
            summary.summary,
            style: const TextStyle(
              fontSize: 14,
              color: kTextPrimary,
              height: 1.55,
            ),
          ),

          if (summary.playerPerformance.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('PLAYER RATINGS', style: kStyleLabel),
            const SizedBox(height: 8),
            ...summary.playerPerformance.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: kBrandSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: kBrandBorder.withOpacity(0.4), width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          p.rating,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kTextBrand,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.player,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                          Text(
                            p.comment,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kTextSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (summary.improvements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('IMPROVEMENTS', style: kStyleLabel),
            const SizedBox(height: 8),
            ...summary.improvements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5, right: 6),
                      child: Icon(Icons.arrow_forward_ios,
                          size: 9, color: kTextBrand),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          color: kTextPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Quick action chip ─────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kSurfaceCard,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: kBorderStrong, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: kTextSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
