// dart
import 'package:flutter/material.dart';
import 'mention_controller.dart';

class MentionSuggestions extends StatefulWidget {
  final MentionController controller;
  final double bottomOffset; // adjust to sit above composer
  const MentionSuggestions({
    super.key,
    required this.controller,
    this.bottomOffset = 110,
  });

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  @override
  void initState() {
    super.initState();
    widget.controller.suggestions.addListener(_onSuggestionsChanged);
  }

  void _onSuggestionsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.suggestions.removeListener(_onSuggestionsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.controller.suggestions.value;
    if (items.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: widget.bottomOffset,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final user = items[i];
              return ListTile(
                leading: CircleAvatar(child: Text(user[0].toUpperCase())),
                title: Text('@$user'),
                onTap: () => widget.controller.insertMention(user),
              );
            },
          ),
        ),
      ),
    );
  }
}
