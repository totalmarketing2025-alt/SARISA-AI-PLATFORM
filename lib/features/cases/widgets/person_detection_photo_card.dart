import 'dart:io';

import 'package:flutter/material.dart';
import 'package:object_detection/object_detection.dart';

import '../models/search_case.dart';
import '../services/person_detection_service.dart';

class PersonDetectionPhotoCard extends StatefulWidget {
  final CasePhoto photo;
  final VoidCallback onDelete;

  const PersonDetectionPhotoCard({
    super.key,
    required this.photo,
    required this.onDelete,
  });

  @override
  State<PersonDetectionPhotoCard> createState() =>
      _PersonDetectionPhotoCardState();
}

class _PersonDetectionPhotoCardState
    extends State<PersonDetectionPhotoCard> {
  List<DetectedObject>? _detections;
  bool _busy = false;
  String? _error;

  Future<void> _analyze() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final results = await PersonDetectionService.instance
          .detectPeople(widget.photo.filePath);

      if (!mounted) return;

      setState(() {
        _detections = results;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.photo.filePath);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (file.existsSync())
                      Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      )
                    else
                      const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    if (_detections != null && file.existsSync())
                      CustomPaint(
                        painter: _PersonBoxesPainter(
                          detections: _detections!,
                        ),
                      ),
                    if (_busy)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              widget.photo.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
          if (_detections != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _detections!.isEmpty
                    ? '0 PERSON CANDIDATES'
                    : '${_detections!.length} CANDIDATE(S) • '
                        '${(_detections!.map((e) => e.score).reduce(
                              (a, b) => a > b ? a : b,
                            ) * 100).round()}% MAX',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                'Analysis failed: $_error',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Colors.red),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: _busy ? null : _analyze,
                  icon: const Icon(Icons.person_search, size: 17),
                  label: Text(
                    _detections == null ? 'ANALYZE' : 'REANALYZE',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete photo',
                onPressed: _busy ? null : widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonBoxesPainter extends CustomPainter {
  final List<DetectedObject> detections;

  _PersonBoxesPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    final imageSize = detections.first.originalSize;
    if (imageSize.width <= 0 || imageSize.height <= 0) return;

    final scale = (size.width / imageSize.width)
        .clamp(0.0, size.height / imageSize.height);
    final fittedWidth = imageSize.width * scale;
    final fittedHeight = imageSize.height * scale;
    final offsetX = (size.width - fittedWidth) / 2;
    final offsetY = (size.height - fittedHeight) / 2;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    for (final detection in detections) {
      final box = detection.boundingBox;

      final rect = Rect.fromLTRB(
        offsetX + box.left * scale,
        offsetY + box.top * scale,
        offsetX + box.right * scale,
        offsetY + box.bottom * scale,
      );

      canvas.drawRect(rect, paint);

      final label =
          'PERSON ${(detection.score * 100).toStringAsFixed(0)}%';

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        (rect.top - textPainter.height - 4).clamp(0.0, size.height),
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRect(labelRect, fillPaint);
      textPainter.paint(
        canvas,
        Offset(labelRect.left + 4, labelRect.top + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PersonBoxesPainter oldDelegate) =>
      oldDelegate.detections != detections;
}
