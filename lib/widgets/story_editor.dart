// lib/widgets/story_editor.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For RepaintBoundary
import 'package:flutter_drawing_board/flutter_drawing_board.dart'; // 0.4.4+2
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// A minimal story editor that:
/// 1. Displays a background image (user's chosen File).
/// 2. Lets the user draw over the image with flutter_drawing_board.
/// 3. Allows adding text widgets on top.
/// 4. Captures the entire stack as a PNG screenshot using RepaintBoundary.
class StoryEditor extends StatefulWidget {
  final VoidCallback onSave;
  final File? imageFile;

  const StoryEditor({
    Key? key,
    required this.onSave,
    this.imageFile,
  }) : super(key: key);

  @override
  _StoryEditorState createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  /// Key for capturing screenshot of the entire editor
  final GlobalKey _editorKey = GlobalKey();

  /// Drawing controller from flutter_drawing_board
  final DrawingController _drawingController = DrawingController();

  /// List of text widgets the user has added
  final List<_TextWidgetData> _textWidgets = [];

  /// Example style for newly added text
  TextStyle _currentTextStyle = const TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  @override
  void dispose() {
    _drawingController.dispose();
    super.dispose();
  }

  /// Captures the entire widget (background image, drawing, text)
  /// as a PNG using RepaintBoundary.
  Future<Uint8List?> _capturePng() async {
    try {
      final boundary = _editorKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Convert boundary to image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing PNG: $e');
      return null;
    }
  }

  /// Saves the story by capturing a screenshot of the entire editor
  /// and writing it to a temp file.
  Future<void> _saveStory() async {
    if (widget.imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected for editing.')),
      );
      return;
    }

    try {
      final Uint8List? pngBytes = await _capturePng();
      if (pngBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image.')),
        );
        return;
      }

      // Write screenshot to a temp file
      final tempDir = await getTemporaryDirectory();
      final combinedPath = p.join(
        tempDir.path,
        'story_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final combinedFile = File(combinedPath);
      await combinedFile.writeAsBytes(pngBytes);

      // Do something with combinedFile (upload to Firebase, etc.)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story created successfully!')),
      );

      widget.onSave();
      Navigator.pop(context, combinedFile);
    } catch (e) {
      debugPrint('Error saving story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving story: $e')),
      );
    }
  }

  /// Adds a text widget to the stack
  void _addText() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        String userText = '';
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add Text",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextField(
                autofocus: true,
                onChanged: (val) => userText = val,
                decoration: const InputDecoration(
                  hintText: "Enter your text here",
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (userText.trim().isNotEmpty) {
                    setState(() {
                      _textWidgets.add(
                        _TextWidgetData(
                          text: userText.trim(),
                          style: _currentTextStyle,
                          position: const Offset(100, 100),
                        ),
                      );
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Main UI: RepaintBoundary -> Stack -> [Background, DrawingBoard, Text]
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Story Editor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveStory,
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _editorKey,
        child: Stack(
          children: [
            // BACKGROUND: show the user's chosen image
            if (widget.imageFile != null)
              Positioned.fill(
                child: Image.file(
                  widget.imageFile!,
                  fit: BoxFit.cover,
                ),
              ),
            // DRAWING BOARD: requires the `background` named parameter
            // in version 0.4.4+2
            // We'll use a simple Container as the background.
            Positioned.fill(
              child: DrawingBoard(
                controller: _drawingController,
                background: Container(color: Colors.transparent),
              ),
            ),
            // TEXT WIDGETS
            for (final tw in _textWidgets)
              Positioned(
                left: tw.position.dx,
                top: tw.position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      tw.position += Offset(details.delta.dx, details.delta.dy);
                    });
                  },
                  child: Text(tw.text, style: tw.style),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addText,
        child: const Icon(Icons.text_fields),
      ),
    );
  }
}

/// Simple model for text widgets
class _TextWidgetData {
  String text;
  TextStyle style;
  Offset position;

  _TextWidgetData({
    required this.text,
    required this.style,
    required this.position,
  });
}
