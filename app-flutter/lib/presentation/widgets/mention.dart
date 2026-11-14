import 'package:flutter/material.dart';

import '../theme.dart';

class MentionMatch {
  const MentionMatch(this.start, this.query);
  final int start;
  final String query;
}

/// The `@word` being typed at [caret], if any.
MentionMatch? activeMention(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final head = text.substring(0, caret);
  final at = head.lastIndexOf('@');
  if (at < 0) return null;
  if (at > 0 && !RegExp(r'[\s(]').hasMatch(head[at - 1])) return null;
  final query = head.substring(at + 1);
  if (RegExp(r'\s').hasMatch(query) || query.length > 24) return null;
  return MentionMatch(at, query);
}

/// Case-insensitive prefix match on the first word of each display name.
List<String> suggestMentions(
  String query,
  Iterable<String> candidates, {
  int limit = 4,
}) {
  final q = query.replaceAll('@', '').toLowerCase();
  final seen = <String>{};
  final out = <String>[];
  for (final raw in candidates) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final handle = name.split(RegExp(r'\s+')).first;
    if (handle.length < 2) continue;
    if (!handle.toLowerCase().startsWith(q)) continue;
    if (!seen.add(handle.toLowerCase())) continue;
    out.add(handle);
    if (out.length == limit) break;
  }
  return out;
}

String applyMention(String text, MentionMatch match, String handle) {
  final before = text.substring(0, match.start);
  final after = text.substring(match.start + 1 + match.query.length);
  final separator = after.isEmpty || !after.startsWith(' ') ? ' ' : '';
  return '$before@$handle$separator$after';
}

List<String> mentionedHandles(String text) => RegExp(r'@([A-Za-z0-9_]{2,24})')
    .allMatches(text)
    .map((m) => m.group(1)!)
    .toSet()
    .toList();

/// Text field with an inline suggestion strip. Submitting is blocked while a
/// suggestion is open so a tap on a name never also sends the message.
class MentionInput extends StatefulWidget {
  const MentionInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hint,
    this.candidates = const [],
    this.lines = 1,
    this.maxLength,
    this.onSubmitted,
    this.fieldKey,
    this.controller,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final List<String> candidates;
  final int lines;
  final int? maxLength;
  final VoidCallback? onSubmitted;
  final Key? fieldKey;
  final TextEditingController? controller;
  @override
  State<MentionInput> createState() => _MentionInputState();
}

class _MentionInputState extends State<MentionInput> {
  late final bool _ownsController = widget.controller == null;
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.value);
  MentionMatch? _match;
  List<String> _suggestions = const [];

  void _onChanged(String value) {
    final m = activeMention(value, _controller.selection.baseOffset);
    setState(() {
      _match = m;
      _suggestions = m == null
          ? const []
          : suggestMentions(m.query, widget.candidates);
    });
    widget.onChanged(value);
  }

  void _apply(String handle) {
    final text = _controller.text;
    final m = _match;
    if (m == null) return;
    final next = applyMention(text, m, handle);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {
      _match = null;
      _suggestions = const [];
    });
    widget.onChanged(next);
  }

  @override
  void didUpdateWidget(covariant MentionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = widget.controller;
    if (external != null && external.text != widget.value) {
      external.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextField(
        key: widget.fieldKey,
        controller: _controller,
        onChanged: _onChanged,
        maxLines: widget.lines,
        maxLength: widget.maxLength,
        textInputAction: widget.lines > 1
            ? TextInputAction.newline
            : TextInputAction.send,
        onSubmitted: (_) {
          if (_suggestions.isEmpty) widget.onSubmitted?.call();
        },
        decoration: InputDecoration(
          hintText: widget.hint,
          counterText: '',
        ),
      ),
      if (_suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in _suggestions)
                ActionChip(
                  avatar: Icon(
                    Icons.alternate_email,
                    size: 14,
                    color: context.nx.accentBrand,
                  ),
                  label: Text(name),
                  onPressed: () => _apply(name),
                ),
            ],
          ),
        ),
    ],
  );
}

