import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class StreamingTypewriterText extends StatefulWidget {
  final String text;
  final Duration speed;
  final VoidCallback? onComplete;
  final MarkdownStyleSheet? styleSheet;
  final bool isStreaming;

  const StreamingTypewriterText({
    super.key,
    required this.text,
    this.speed = const Duration(milliseconds: 20),
    this.onComplete,
    this.styleSheet,
    this.isStreaming = true,
  });

  @override
  State<StreamingTypewriterText> createState() => _StreamingTypewriterTextState();
}

class _StreamingTypewriterTextState extends State<StreamingTypewriterText> with TickerProviderStateMixin {
  // The stable text that has fully finished animating
  String _stableText = "";
  // List of characters currently animating
  final List<_AnimatingChar> _animatingChars = [];
  
  // Timer for adding new characters
  Timer? _typewriterTimer;
  int _currentIndex = 0;

  // Global Fade Controller for Static Mode
  late AnimationController _globalFadeController;
  late Animation<double> _globalFadeAnimation;

  @override
  void initState() {
    super.initState();
    _globalFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _globalFadeAnimation = CurvedAnimation(
      parent: _globalFadeController,
      curve: Curves.easeOut,
    );

    if (widget.isStreaming) {
      _startTyping();
    } else {
      _stableText = widget.text;
      _globalFadeController.value = 1.0; // Directly show without animation
    }
  }

  @override
  void didUpdateWidget(StreamingTypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle mode switch or text updates
    if (widget.isStreaming != oldWidget.isStreaming) {
       if (widget.isStreaming) {
         // Switch to streaming (rare case, maybe clear and type?)
         _stableText = "";
         _currentIndex = 0;
         _startTyping();
       } else {
         // Switch to static (streaming finished)
         _finalizeTyping();
       }
    } else if (widget.isStreaming && widget.text != oldWidget.text) {
      // If text updated (streaming), ensure timer is running
      if (_typewriterTimer == null || !_typewriterTimer!.isActive) {
        _startTyping();
      }
    } else if (!widget.isStreaming && widget.text != oldWidget.text) {
       // Static update (maybe refresh?)
       setState(() {
         _stableText = widget.text;
       });
       // If empty -> non-empty, maybe fade?
       // DISABLED for performance and to avoid double animation
       // if (oldWidget.text.isEmpty && widget.text.isNotEmpty) {
       //    _globalFadeController.forward(from: 0);
       // }
    }
  }

  void _finalizeTyping() {
    _typewriterTimer?.cancel();
    // Complete all animations immediately
    for (var char in _animatingChars) {
      char.controller.dispose();
    }
    setState(() {
      _animatingChars.clear();
      _stableText = widget.text;
      _currentIndex = widget.text.length;
    });
    // Ensure fully visible
    _globalFadeController.value = 1.0; 
  }

  void _startTyping() {
    _typewriterTimer?.cancel();
    
    // Adjust speed based on lag? 
    // For now, fixed speed as requested, but "Buffer compensation" suggested.
    // If widget.text.length - _currentIndex is large, speed up?
    
    _typewriterTimer = Timer.periodic(widget.speed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Check lag
      int pendingCount = widget.text.length - _currentIndex;
      if (pendingCount <= 0) {
        timer.cancel();
        widget.onComplete?.call();
        return;
      }

      // Speed up if falling behind
      // If pending > 10 chars, process multiple?
      int charsToProcess = 1;
      if (pendingCount > 20) charsToProcess = 3;
      else if (pendingCount > 5) charsToProcess = 2;

      for (int i = 0; i < charsToProcess; i++) {
        if (_currentIndex < widget.text.length) {
          _addNextChar();
        }
      }
    });
  }

  void _addNextChar() {
    if (_currentIndex >= widget.text.length) return;

    final char = widget.text[_currentIndex];
    _currentIndex++;

    // Create animation controller for this char
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Slower individual animation
    );

    final animChar = _AnimatingChar(
      char: char,
      controller: controller,
      onComplete: () {
        if (mounted) {
          setState(() {
            _stableText += char;
            _animatingChars.removeWhere((element) => element.controller == controller);
            controller.dispose();
          });
        }
      },
    );

    setState(() {
      _animatingChars.add(animChar);
    });

    controller.forward();
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _globalFadeController.dispose();
    for (var char in _animatingChars) {
      char.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.5);
    final styleSheet = widget.styleSheet ?? MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: defaultStyle,
    );

    // If static mode, use global fade animation
    if (!widget.isStreaming) {
      return AnimatedBuilder(
        animation: _globalFadeAnimation,
        builder: (context, child) {
          final progress = _globalFadeAnimation.value;
          final blur = (1.0 - progress) * 5.0;
          final opacity = progress.clamp(0.0, 1.0);
          
          return Opacity(
            opacity: opacity,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: child,
            ),
          );
        },
        child: MarkdownBody(
          data: _stableText,
          selectable: true,
          styleSheet: styleSheet,
          fitContent: true,
        ),
      );
    }

    // Streaming Mode: Typewriter Effect
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_stableText.isNotEmpty)
          MarkdownBody(
            data: _stableText,
            selectable: true,
            styleSheet: styleSheet,
            fitContent: true,
          ),
        
        if (_animatingChars.isNotEmpty)
          RichText(
            text: TextSpan(
              children: _animatingChars.map((ac) {
                return WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: AnimatedBuilder(
                    animation: ac.controller,
                    builder: (context, child) {
                      // Blur: 10 -> 0
                      // Opacity: 0 -> 1
                      final double progress = ac.controller.value;
                      final double blur = (1.0 - progress) * 5.0; // Max blur 5
                      final double opacity = progress.clamp(0.0, 1.0);

                      return Opacity(
                        opacity: opacity,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                          child: Text(
                            ac.char,
                            style: defaultStyle,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _AnimatingChar {
  final String char;
  final AnimationController controller;
  final VoidCallback onComplete;

  _AnimatingChar({
    required this.char,
    required this.controller,
    required this.onComplete,
  }) {
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete();
      }
    });
  }
}
