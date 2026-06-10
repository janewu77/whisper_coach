import 'dart:async';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/foundation.dart' show kIsWeb;
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

enum _InputMode { voice, text }

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
  Timer? _matchClock;
  bool _sending = false;
  bool _recording = false;
  bool _changingRecordingState = false;
  bool _summaryDone = false;
  _InputMode _inputMode = _InputMode.voice;
  String? _recordingPath;
  String _recordingFilename = 'note.m4a';
  String _recordingMimeType = 'audio/mp4';

  int _matchMinute = 0;

  // ── Countdown clock (half/period timer) ──────────────────────────────────
  Timer? _countdown;
  int _countdownSetMin = 45; // chosen length in minutes
  int _remainingSec = 0; // > 0 while running/paused
  bool _countdownRunning = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      SystemMessage(
          'Match started. Voice input is ready. Speak to log events and get suggestions.'),
    );
    _matchClock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _matchMinute++);
      }
    });
  }

  @override
  void dispose() {
    _matchClock?.cancel();
    _countdown?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Countdown clock ───────────────────────────────────────────────────────

  String get _countdownLabel {
    final m = (_remainingSec ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startCountdown() {
    setState(() {
      _remainingSec = _countdownSetMin * 60;
      _countdownRunning = true;
    });
    _runCountdown();
  }

  void _runCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSec <= 1) {
        _countdown?.cancel();
        setState(() {
          _remainingSec = 0;
          _countdownRunning = false;
          _messages.add(SystemMessage('⏱ $_countdownSetMin min are up!'));
        });
        _scrollToBottom();
      } else {
        setState(() => _remainingSec--);
      }
    });
  }

  void _pauseCountdown() {
    _countdown?.cancel();
    setState(() => _countdownRunning = false);
  }

  void _resumeCountdown() {
    setState(() => _countdownRunning = true);
    _runCountdown();
  }

  void _resetCountdown() {
    _countdown?.cancel();
    setState(() {
      _remainingSec = 0;
      _countdownRunning = false;
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

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    late final RecordConfig config;
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        _recordingFilename = 'note_$timestamp.webm';
        _recordingMimeType = 'audio/webm';
      } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recordingFilename = 'note_$timestamp.m4a';
        _recordingMimeType = 'audio/mp4';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.wav);
        _recordingFilename = 'note_$timestamp.wav';
        _recordingMimeType = 'audio/wav';
      }
      // record_web returns a Blob URL from stop(); it does not write a file.
      _recordingPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recordingFilename = 'note_$timestamp.m4a';
      _recordingMimeType = 'audio/mp4';
      _recordingPath = '${dir.path}/$_recordingFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }

    await _recorder.start(
      config,
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
    final file = XFile(
      path,
      name: _recordingFilename,
      mimeType: _recordingMimeType,
    );
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live match'),
            Text(
              'vs ${widget.args.opponent} · $_matchMinute\'',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kStyleSecondary.copyWith(fontSize: 12, height: 1.2),
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
                    border: Border.all(
                      color: kRedFg.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
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
          // Countdown clock (set minutes → start → mm:ss)
          _buildCountdownBar(),
          const Divider(height: 1),

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

  Widget _buildCountdownBar() {
    final active = _remainingSec > 0 || _countdownRunning;
    final urgent = active && _remainingSec <= 60;
    return Container(
      color: kSurfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              size: 18, color: urgent ? kRedFg : kTextSecondary),
          const SizedBox(width: 8),
          if (!active) ...[
            // Idle: pick the length, then start.
            IconButton(
              tooltip: '-5 min',
              visualDensity: VisualDensity.compact,
              onPressed: _countdownSetMin > 5
                  ? () => setState(() => _countdownSetMin -= 5)
                  : null,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
            ),
            Text(
              '$_countdownSetMin min',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: '+5 min',
              visualDensity: VisualDensity.compact,
              onPressed: _countdownSetMin < 90
                  ? () => setState(() => _countdownSetMin += 5)
                  : null,
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _startCountdown,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Start'),
            ),
          ] else ...[
            // Running / paused: mm:ss + pause/resume + reset.
            Text(
              _countdownLabel,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: urgent ? kRedFg : kTextPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            if (!_countdownRunning)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kSurfacePage,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text('Paused',
                    style: kStyleLabel.copyWith(
                        fontSize: 10, letterSpacing: 0)),
              ),
            const Spacer(),
            IconButton(
              tooltip: _countdownRunning ? 'Pause' : 'Resume',
              visualDensity: VisualDensity.compact,
              onPressed:
                  _countdownRunning ? _pauseCountdown : _resumeCountdown,
              icon: Icon(
                _countdownRunning
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 24,
                color: kTextBrand,
              ),
            ),
            IconButton(
              tooltip: 'Reset',
              visualDensity: VisualDensity.compact,
              onPressed: _resetCountdown,
              icon: const Icon(Icons.stop_circle_outlined,
                  size: 24, color: kTextSecondary),
            ),
          ],
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
    final inputLocked = _recording || _changingRecordingState || _sending;

    return SafeArea(
      top: false,
      child: Container(
        color: kSurfaceCard,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick actions
            SizedBox(
              height: 36,
              child: ListView(
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
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _inputMode == _InputMode.voice
                  ? _buildVoiceInput()
                  : _buildTextInput(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _CompactInputModeButton(
                mode: _inputMode,
                enabled: !inputLocked,
                onTap: () {
                  setState(() {
                    _inputMode = _inputMode == _InputMode.voice
                        ? _InputMode.text
                        : _InputMode.voice;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInput() {
    return Column(
      key: const ValueKey('voice-input'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: _recording ? 'Stop voice recording' : 'Start voice recording',
          child: GestureDetector(
            key: const Key('voice-record-button'),
            onTap: _sending ? null : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: _recording ? kRedFg : kBrand,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _recording ? kRedBg : kBrandSubtle,
                  width: 7,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_recording ? kRedFg : kBrand).withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                _recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _recording ? 'Recording... Tap to stop' : 'Tap to speak',
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _recording
              ? 'Your note will be sent when recording stops'
              : 'Describe what is happening on the pitch',
          style: kStyleSecondary,
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Row(
      key: const ValueKey('text-input'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('live-note-text-field'),
            controller: _textCtrl,
            autofocus: true,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendText(),
            decoration: const InputDecoration(
              hintText: 'Type event or ask for advice...',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Send text note',
          child: GestureDetector(
            key: const Key('send-text-note-button'),
            onTap: _sending ? null : _sendText,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _sending ? kBorderStrong : kBrand,
                borderRadius: BorderRadius.circular(kRadiusInput),
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactInputModeButton extends StatelessWidget {
  final _InputMode mode;
  final bool enabled;
  final VoidCallback onTap;

  const _CompactInputModeButton({
    required this.mode,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final switchToText = mode == _InputMode.voice;
    final foreground = enabled ? kTextSecondary : kTextTertiary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: switchToText ? 'Switch to text input' : 'Switch to voice input',
      child: Material(
        color: kSurfacePage,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            key: switchToText
                ? const Key('text-input-mode-button')
                : const Key('voice-input-mode-button'),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: kBorderHairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  switchToText ? Icons.keyboard_rounded : Icons.mic_rounded,
                  size: 17,
                  color: foreground,
                ),
                const SizedBox(width: 5),
                Text(
                  switchToText ? 'Text input' : 'Voice input',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
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
        decoration: const BoxDecoration(
          color: kBrand,
          borderRadius: BorderRadius.only(
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
                          color: kBrandBorder.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
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
