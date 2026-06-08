import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../theme.dart';

/// Lets the coach crop the roster photo before import — only the selected
/// region is sent to the extractor. Cropping is done in pure Dart (the `image`
/// package), so it works on web and native with no platform setup.
///
/// Returns the cropped JPEG bytes via `Navigator.pop`, or null if cancelled.
class CropScreen extends StatefulWidget {
  final Uint8List bytes;

  const CropScreen({super.key, required this.bytes});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  // Source image, orientation-baked and capped so display matches the crop math.
  img.Image? _src;
  String? _error;
  bool _processing = false;

  // Crop rectangle in normalized image coords (0..1), as LTRB.
  Rect _crop = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92);

  static const double _maxEdge = 2400; // cap long edge for snappy crop/encode
  static const double _minSize = 0.08; // smallest crop fraction per axis
  static const double _handle = 26;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      var decoded = img.decodeImage(widget.bytes);
      if (decoded == null) {
        setState(() => _error = 'Could not read this image.');
        return;
      }
      decoded = img.bakeOrientation(decoded); // apply EXIF rotation
      final longEdge = math.max(decoded.width, decoded.height);
      if (longEdge > _maxEdge) {
        final scale = _maxEdge / longEdge;
        decoded = img.copyResize(
          decoded,
          width: (decoded.width * scale).round(),
          height: (decoded.height * scale).round(),
        );
      }
      setState(() => _src = decoded);
    } catch (e) {
      setState(() => _error = 'Could not read this image.');
    }
  }

  Future<void> _confirm() async {
    final src = _src;
    if (src == null) return;
    setState(() => _processing = true);
    // Yield a frame so the spinner shows before the (sync) crop work.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    try {
      final x = (_crop.left * src.width).round().clamp(0, src.width - 1);
      final y = (_crop.top * src.height).round().clamp(0, src.height - 1);
      final w = ((_crop.width) * src.width).round().clamp(1, src.width - x);
      final h = ((_crop.height) * src.height).round().clamp(1, src.height - y);
      final cropped = img.copyCrop(src, x: x, y: y, width: w, height: h);
      final out = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
      if (mounted) Navigator.of(context).pop(out);
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Crop failed: $e')));
      }
    }
  }

  // ── crop-rect mutations (deltas are in widget pixels over the shown image) ──

  void _moveBy(Offset d, Rect shown) {
    var dx = d.dx / shown.width;
    var dy = d.dy / shown.height;
    dx = dx.clamp(-_crop.left, 1 - _crop.right);
    dy = dy.clamp(-_crop.top, 1 - _crop.bottom);
    setState(() => _crop = _crop.translate(dx, dy));
  }

  void _dragCorner(String which, Offset d, Rect shown) {
    final dnx = d.dx / shown.width;
    final dny = d.dy / shown.height;
    var l = _crop.left, t = _crop.top, r = _crop.right, b = _crop.bottom;
    if (which.contains('l')) l = (l + dnx).clamp(0.0, r - _minSize);
    if (which.contains('r')) r = (r + dnx).clamp(l + _minSize, 1.0);
    if (which.contains('t')) t = (t + dny).clamp(0.0, b - _minSize);
    if (which.contains('b')) b = (b + dny).clamp(t + _minSize, 1.0);
    setState(() => _crop = Rect.fromLTRB(l, t, r, b));
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select roster area'),
        actions: [
          if (_src != null && !_processing)
            TextButton(
              onPressed: _confirm,
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(_error!,
                  style: kStyleBody.copyWith(color: Colors.white)),
            )
          : _src == null
              ? const Center(child: CircularProgressIndicator(color: kBrand))
              : Column(
                  children: [
                    Expanded(child: _buildCropArea()),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Drag the corners to keep only the player list.',
                              textAlign: TextAlign.center,
                              style: kStyleSecondary.copyWith(
                                  color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _processing ? null : _confirm,
                              icon: _processing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.crop, size: 18),
                              label: Text(
                                  _processing ? 'Cropping…' : 'Crop & continue'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCropArea() {
    final src = _src!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        final scale =
            math.min(boxW / src.width, boxH / src.height);
        final dispW = src.width * scale;
        final dispH = src.height * scale;
        final shown = Rect.fromLTWH(
          (boxW - dispW) / 2,
          (boxH - dispH) / 2,
          dispW,
          dispH,
        );
        // Crop rectangle in widget coordinates.
        final c = Rect.fromLTRB(
          shown.left + _crop.left * shown.width,
          shown.top + _crop.top * shown.height,
          shown.left + _crop.right * shown.width,
          shown.top + _crop.bottom * shown.height,
        );

        return Stack(
          children: [
            Positioned.fromRect(
              rect: shown,
              child: Image.memory(widget.bytes, fit: BoxFit.fill),
            ),
            // Dim everything outside the crop rectangle.
            ..._dimRects(Rect.fromLTWH(0, 0, boxW, boxH), c),
            // Move the whole rectangle by dragging inside it.
            Positioned.fromRect(
              rect: c,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (d) => _moveBy(d.delta, shown),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: kBrand, width: 2),
                  ),
                ),
              ),
            ),
            _cornerHandle('tl', Offset(c.left, c.top), shown),
            _cornerHandle('tr', Offset(c.right, c.top), shown),
            _cornerHandle('bl', Offset(c.left, c.bottom), shown),
            _cornerHandle('br', Offset(c.right, c.bottom), shown),
          ],
        );
      },
    );
  }

  List<Widget> _dimRects(Rect box, Rect c) {
    const dim = Color(0x99000000);
    Widget r(double l, double t, double w, double h) => Positioned(
          left: l,
          top: t,
          width: math.max(0, w),
          height: math.max(0, h),
          child: const IgnorePointer(child: ColoredBox(color: dim)),
        );
    return [
      r(0, 0, box.width, c.top), // above
      r(0, c.bottom, box.width, box.height - c.bottom), // below
      r(0, c.top, c.left, c.height), // left
      r(c.right, c.top, box.width - c.right, c.height), // right
    ];
  }

  Widget _cornerHandle(String which, Offset center, Rect shown) {
    return Positioned(
      left: center.dx - _handle / 2,
      top: center.dy - _handle / 2,
      width: _handle,
      height: _handle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _dragCorner(which, d.delta, shown),
        child: Center(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: kBrand,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
