import 'package:flutter/material.dart';

enum PrototypeViewState { defaultState, loading, empty, error }

class ScreenPrototypeDefinition {
  const ScreenPrototypeDefinition({
    required this.featureGroup,
    required this.screenName,
    required this.screenGoal,
    required this.primaryActionLabel,
    required this.entryPoint,
    required this.exitPoint,
    required this.transitionNote,
    required this.placeholders,
  });

  final String featureGroup;
  final String screenName;
  final String screenGoal;
  final String primaryActionLabel;
  final String entryPoint;
  final String exitPoint;
  final String transitionNote;
  final List<String> placeholders;
}

class PrototypeScreenCard extends StatelessWidget {
  const PrototypeScreenCard({
    super.key,
    required this.definition,
    required this.viewState,
  });

  final ScreenPrototypeDefinition definition;
  final PrototypeViewState viewState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(definition.featureGroup)),
                Chip(label: Text(_stateLabel(viewState))),
              ],
            ),
            const SizedBox(height: 12),
            Text(definition.screenName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(definition.screenGoal, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _PrototypeFrame(
              state: viewState,
              primaryActionLabel: definition.primaryActionLabel,
              placeholders: definition.placeholders,
            ),
            const SizedBox(height: 12),
            Text('Entry: ${definition.entryPoint}', style: theme.textTheme.bodySmall),
            Text('Exit: ${definition.exitPoint}', style: theme.textTheme.bodySmall),
            Text(
              'Transition: ${definition.transitionNote}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(PrototypeViewState state) {
    switch (state) {
      case PrototypeViewState.defaultState:
        return 'Default';
      case PrototypeViewState.loading:
        return 'Loading';
      case PrototypeViewState.empty:
        return 'Empty';
      case PrototypeViewState.error:
        return 'Error';
    }
  }
}

class _PrototypeFrame extends StatelessWidget {
  const _PrototypeFrame({
    required this.state,
    required this.primaryActionLabel,
    required this.placeholders,
  });

  final PrototypeViewState state;
  final String primaryActionLabel;
  final List<String> placeholders;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(12),
      child: switch (state) {
        PrototypeViewState.defaultState => Column(
            children: [
              for (final text in placeholders)
                _PlaceholderRow(label: text, isMuted: false),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {},
                  child: Text(primaryActionLabel),
                ),
              ),
            ],
          ),
        PrototypeViewState.loading => Column(
            children: const [
              _PlaceholderRow(label: 'Loading block', isMuted: true),
              _PlaceholderRow(label: 'Loading block', isMuted: true),
              _PlaceholderRow(label: 'Loading block', isMuted: true),
            ],
          ),
        PrototypeViewState.empty => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PlaceholderRow(label: 'No data available', isMuted: false),
              const SizedBox(height: 8),
              Text(
                'Show CTA that helps the user create or discover content.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {},
                child: Text(primaryActionLabel),
              ),
            ],
          ),
        PrototypeViewState.error => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlaceholderRow(
                label: 'Something went wrong',
                isMuted: false,
                isError: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Display actionable error copy and a retry path.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('Retry'),
              ),
            ],
          ),
      },
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({
    required this.label,
    required this.isMuted,
    this.isError = false,
  });

  final String label;
  final bool isMuted;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? scheme.errorContainer
            : isMuted
                ? scheme.surfaceContainerHighest
                : scheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isError ? scheme.onErrorContainer : null,
            ),
      ),
    );
  }
}
