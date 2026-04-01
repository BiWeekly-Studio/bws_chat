import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// ChatInputBar
//
// The bottom input bar for the chat room screen.
//
//   • Text input with hint "메시지를 입력하세요"
//   • Image picker button (gallery icon) on the left
//   • Send button on the right – visible only when text is non-empty
//   • Expands up to 5 lines; shrinks back when cleared
//   • Safe-area aware (respects bottom padding)
//
// Callbacks:
//   onSubmit(text)       – called when send button tapped or keyboard action
//   onImagePick()        – called when gallery icon tapped
//   onTypingChanged(str) – called on every keystroke for typing-indicator updates
// ---------------------------------------------------------------------------

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    this.onSubmit,
    this.onImagePick,
    this.onTypingChanged,
    this.primaryColor = const Color(0xFF4F86F7),
    this.backgroundColor = Colors.white,
    this.isUploadingImage = false,
    this.maxLength = 1000,
  });

  final ValueChanged<String>? onSubmit;
  final VoidCallback? onImagePick;
  final ValueChanged<String>? onTypingChanged;
  final Color primaryColor;
  final Color backgroundColor;

  /// Show a loading spinner instead of the gallery icon while uploading.
  final bool isUploadingImage;

  final int maxLength;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSubmit?.call(text);
  }

  Color _contrastColor(Color bg) {
    return bg.computeLuminance() > 0.4
        ? const Color(0xFF1A1A1A)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Gallery / upload button
          widget.isUploadingImage
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.image_outlined,
                      color: Color(0xFF757575)),
                  onPressed: widget.onImagePick,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: '사진 보내기',
                ),
          const SizedBox(width: 4),
          // Text field
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (_, value, child) => child!,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: widget.onTypingChanged,
                  onSubmitted: (_) => _handleSubmit(),
                  maxLines: null,
                  maxLength: widget.maxLength,
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                  style: const TextStyle(fontSize: 15),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button (animated – appears when text is non-empty)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (_, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? _handleSubmit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasText
                        ? widget.primaryColor
                        : const Color(0xFFDDDDDD),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: hasText
                        ? _contrastColor(widget.primaryColor)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
