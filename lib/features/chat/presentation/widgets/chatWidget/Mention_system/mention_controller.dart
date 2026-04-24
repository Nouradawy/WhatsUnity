// dart
import 'package:flutter/material.dart';

class MentionController {
  final TextEditingController textController;
  final List<String> allUsers; // e.g. ['alice','bob','admin','everyone']
  final ValueNotifier<List<String>> suggestions = ValueNotifier([]);
  int? _atIndex; // index of the active '@' in the text

  MentionController(this.textController, {required this.allUsers}) {
    textController.addListener(_onTextChanged);
    _onTextChanged(); // init
  }

  void _onTextChanged() {
    final sel = textController.selection;
    final cursor = sel.isValid ? sel.start : textController.text.length;
    if (cursor <= 0) {
      _clear();
      return;
    }

    final upto = textController.text.substring(0, cursor);
    final lastAt = upto.lastIndexOf('@');
    if (lastAt == -1) {
      _clear();
      return;
    }

    // Ensure '@' is start or preceded by whitespace
    if (lastAt > 0) {
      final prev = upto[lastAt - 1];
      if (prev != ' ' && prev != '\n' && prev != '\t') {
        _clear();
        return;
      }
    }

    final query = upto.substring(lastAt + 1);
    // If query contains whitespace or punctuation, abort
    if (query.contains(RegExp(r'[\s,.;:/\\]'))) {
      _clear();
      return;
    }

    _atIndex = lastAt;
    if (query.isEmpty) {
      // show a few top suggestions
      suggestions.value = allUsers.take(6).toList();
    } else {
      final q = query.toLowerCase();
      final filtered = allUsers
          .where((u) => u.toLowerCase().contains(q))
          .take(6)
          .toList();
      suggestions.value = filtered;
    }
  }

  void insertMention(String username) {
    final text = textController.text;
    final sel = textController.selection;
    final cursor = sel.isValid ? sel.start : text.length;
    final at = _atIndex;
    if (at == null || at > cursor) return;

    final prefix = text.substring(0, at);
    final suffix = text.substring(cursor);
    final inserted = '@$username ';
    final newText = '$prefix$inserted$suffix';

    final newCursorPos = (prefix + inserted).length;
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    // clear suggestions
    suggestions.value = [];
    _atIndex = null;
  }

  void _clear() {
    _atIndex = null;
    if (suggestions.value.isNotEmpty) suggestions.value = [];
  }

  void dispose() {
    textController.removeListener(_onTextChanged);
    suggestions.dispose();
  }
}
