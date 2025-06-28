import 'package:flutter/material.dart';

class StreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isStreaming;
  final Duration wordDelay;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.isStreaming = false,
    this.wordDelay = const Duration(milliseconds: 80),
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText>
    with TickerProviderStateMixin {
  late AnimationController _cursorController;
  late Animation<double> _cursorAnimation;
  String _displayText = '';
  int _currentWordIndex = 0;
  List<String> _words = [];

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cursorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cursorController,
      curve: Curves.easeInOut,
    ));

    _initializeText();
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.isStreaming != oldWidget.isStreaming) {
      _initializeText();
    }
  }

  void _initializeText() {
    _words = widget.text.split(' ');
    // Always show the current text - streaming is handled by ChatService
    _displayText = widget.text;
    _currentWordIndex = _words.length;

    if (widget.isStreaming) {
      _cursorController.repeat(reverse: true);
    } else {
      _cursorController.stop();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _displayText),
          if (widget.isStreaming)
            WidgetSpan(
              child: AnimatedBuilder(
                animation: _cursorAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _cursorAnimation.value,
                    child: Container(
                      width: 2,
                      height: (widget.style?.fontSize ?? 16) * 1.2,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: widget.style?.color ?? Colors.black,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
