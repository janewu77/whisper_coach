import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/lineup.dart';
import '../models/summary.dart';
import '../theme.dart';

/// Post-match view: the formation with starters + subs, and a detailed
/// AI-written report synthesized from the live match notes (not raw notes).
class MatchSummaryScreen extends StatefulWidget {
  final int matchId;
  final String opponent;

  const MatchSummaryScreen({
    super.key,
    required this.matchId,
    required this.opponent,
  });

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  Lineup? _lineup;
  Summary? _summary;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  // Coach prompt for the report (style / extra info) — typed or spoken.
  final _instructionsCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  bool _recording = false;
  String _recFilename = 'summary.m4a';
  String _recMime = 'audio/mp4';
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (_generating || _loading) return;
    try {
      if (_recording) {
        await _stopVoiceAndRegenerate();
      } else {
        await _startVoice();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _recording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  Future<void> _startVoice() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    late final RecordConfig config;
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        _recFilename = 'summary_$ts.webm';
        _recMime = 'audio/webm';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recFilename = 'summary_$ts.m4a';
        _recMime = 'audio/mp4';
      }
      _recPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recFilename = 'summary_$ts.m4a';
      _recMime = 'audio/mp4';
      _recPath = '${dir.path}/$_recFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopVoiceAndRegenerate() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    setState(() => _generating = true);
    try {
      final summary = await api.getSummaryVoice(
        widget.matchId,
        XFile(path, name: _recFilename, mimeType: _recMime),
      );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await api.getMatch(widget.matchId);
      // Use the stored summary when it exists; otherwise generate it now.
      var summary = await api.getStoredSummary(widget.matchId);
      if (summary == null) {
        setState(() {
          _lineup = details.lineup;
          _generating = true;
          _loading = false;
        });
        summary = await api.getSummary(widget.matchId);
      }
      if (mounted) {
        setState(() {
          _lineup = details.lineup;
          _summary = summary;
          _loading = false;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = dioErrorMessage(e);
          _loading = false;
          _generating = false;
        });
      }
    }
  }

  Future<void> _regenerate() async {
    setState(() => _generating = true);
    try {
      final summary = await api.getSummary(
        widget.matchId,
        instructions: _instructionsCtrl.text.trim(),
      );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfacePage,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Match summary'),
            Text(
              'vs ${widget.opponent}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kStyleSecondary.copyWith(fontSize: 12, height: 1.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Regenerate summary',
            onPressed: (_loading || _generating) ? null : _regenerate,
            icon: const Icon(Icons.refresh_outlined, size: 20),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_generating ? 2.5 : 0.5),
          child: _generating
              ? const LinearProgressIndicator(
                  minHeight: 2.5, color: kBrand, backgroundColor: kBrandSubtle)
              : Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: kStyleSecondary),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  children: [
                    if (_lineup != null) ...[
                      _FormationCard(lineup: _lineup!),
                      const SizedBox(height: 12),
                    ],

                    // Coach prompt for the report + regenerate.
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _instructionsCtrl,
                            maxLines: 1,
                            decoration: InputDecoration(
                              labelText: 'Report wishes (optional)',
                              hintText: _recording
                                  ? 'Listening… tap the mic to stop'
                                  : 'e.g. make it humorous, mention the rain…',
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: _recording
                                    ? 'Stop & regenerate'
                                    : 'Speak your wishes',
                                onPressed:
                                    _generating ? null : _toggleVoice,
                                icon: Icon(
                                  _recording
                                      ? Icons.stop_rounded
                                      : Icons.mic_none_outlined,
                                  size: 20,
                                  color:
                                      _recording ? kRedFg : kTextBrand,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Regenerate summary',
                          onPressed: (_generating || _recording)
                              ? null
                              : _regenerate,
                          style: IconButton.styleFrom(
                            backgroundColor: kBrand,
                            foregroundColor: kTextOnBrand,
                            disabledBackgroundColor: kBorderStrong,
                            fixedSize: const Size(46, 46),
                          ),
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_outlined,
                                  size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_generating && _summary == null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: kBrand),
                            const SizedBox(height: 12),
                            Text('Writing the match report…',
                                style: kStyleSecondary),
                          ],
                        ),
                      )
                    else if (_summary != null)
                      _ReportCard(summary: _summary!),
                  ],
                ),
    );
  }
}

/// Formation + starters (left) and subs (right).
class _FormationCard extends StatelessWidget {
  final Lineup lineup;

  const _FormationCard({required this.lineup});

  Widget _slotRow(LineupSlot s, {required bool starter}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: starter ? kBrandSubtle : kSurfacePage,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              s.position,
              textAlign: TextAlign.center,
              style: kStyleLabel.copyWith(
                fontSize: 9,
                letterSpacing: 0,
                color: starter ? kTextBrand : kTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              s.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kStyleBodyMd.copyWith(
                fontWeight: starter ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          Row(
            children: [
              const Icon(Icons.grid_view_outlined,
                  size: 14, color: kTextBrand),
              const SizedBox(width: 6),
              Text('FORMATION · ${lineup.formation}', style: kStyleLabel),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STARTING · ${lineup.lineup.length}',
                        style: kStyleLabel.copyWith(fontSize: 9)),
                    const SizedBox(height: 6),
                    for (final s in lineup.lineup)
                      _slotRow(s, starter: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SUBS · ${lineup.subs.length}',
                        style: kStyleLabel.copyWith(fontSize: 9)),
                    const SizedBox(height: 6),
                    if (lineup.subs.isEmpty)
                      Text('—',
                          style: kStyleSecondary.copyWith(
                              color: kTextTertiary))
                    else
                      for (final s in lineup.subs)
                        _slotRow(s, starter: false),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The detailed AI match report: narrative, player ratings, improvements.
class _ReportCard extends StatelessWidget {
  final Summary summary;

  const _ReportCard({required this.summary});

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
                'Match report',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextBrand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
