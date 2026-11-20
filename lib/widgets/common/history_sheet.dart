import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/setup_exception.dart';
import '../../models/setup_result.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/generation_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/translation_provider.dart';
import '../../screens/results_screen.dart';
import '../../services/history_service.dart';
import '../common/expansion_badge.dart';

/// Shows a bottom sheet with recent kingdoms and locally saved presets.
void showHistorySheet(BuildContext context, WidgetRef ref,
    {VoidCallback? onOpenResults}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _HistorySheet(onOpenResults: onOpenResults),
  );
}

enum _LibraryAction { exportBackup, restoreBackup, clearHistory }

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet({this.onOpenResults});

  final VoidCallback? onOpenResults;

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final history = state.history;
    final pack = ref.watch(activeTranslationPackProvider).valueOrNull;
    final favorites = state.favorites
        .where((board) => [
              board.savedName,
              board.savedNotes,
              for (final card in [
                ...board.kingdomCards,
                ...board.landscapeCards
              ]) ...[
                card.name,
                pack?.lookup(card.id)?.name ?? '',
              ],
            ].any((text) => text.toLowerCase().contains(_query)))
        .toList();
    final hasEntries = state.favorites.isNotEmpty || history.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
          ),
        ),
        child: Column(
          children: [
            if (state.hadUnreadableEntries)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Some saved kingdoms could not be read.'),
              ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.collections_bookmark_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Kingdom Library',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  PopupMenuButton<_LibraryAction>(
                    tooltip: 'Library actions',
                    onSelected: (action) => switch (action) {
                      _LibraryAction.exportBackup =>
                        _exportBackup(state.favorites),
                      _LibraryAction.restoreBackup => _restoreBackup(),
                      _LibraryAction.clearHistory =>
                        _confirmClearHistory(context, ref),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: _LibraryAction.exportBackup,
                          enabled: !state.isLoading &&
                              !state.couldNotLoad &&
                              state.favorites.isNotEmpty,
                          child: const Text('Export saved kingdoms')),
                      PopupMenuItem(
                          value: _LibraryAction.restoreBackup,
                          enabled: !state.isLoading && !state.couldNotLoad,
                          child: const Text('Restore backup')),
                      if (history.isNotEmpty)
                        const PopupMenuItem(
                            value: _LibraryAction.clearHistory,
                            child: Text('Clear history')),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (state.isLoading)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          semanticsLabel: 'Loading kingdom library')))
            else if (state.couldNotLoad)
              Expanded(
                  child: Center(
                      child: TextButton(
                onPressed: () {
                  ref.read(cardDataServiceProvider).invalidate();
                  ref.invalidate(allCardsProvider);
                  ref.read(historyProvider.notifier).reload();
                },
                child: const Text('Could not load the library. Try again'),
              )))
            else if (!hasEntries)
              const Expanded(child: _EmptyHistory())
            else
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
                  children: [
                    _SectionLabel(
                      icon: Icons.star_rounded,
                      title: 'Saved kingdoms',
                      subtitle: state.favorites.isEmpty
                          ? 'Star any kingdom to keep it locally until you delete it.'
                          : '${state.favorites.length} saved kingdom${state.favorites.length == 1 ? '' : 's'}',
                    ),
                    if (state.favorites.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase()),
                          decoration: const InputDecoration(
                              labelText: 'Search saved kingdoms',
                              prefixIcon: Icon(Icons.search_rounded)),
                        ),
                      ),
                    if (favorites.isEmpty)
                      _SectionEmptyState(
                        icon: Icons.star_border_rounded,
                        message: _query.isEmpty
                            ? 'No saved kingdoms yet.'
                            : 'No saved kingdoms match your search.',
                      )
                    else
                      ...favorites.asMap().entries.map(
                            (entry) => _HistoryTile(
                              result: entry.value,
                              index: entry.key,
                              isFavorite: true,
                              leadingIcon: Icons.star_rounded,
                              onTap: () =>
                                  _openResult(context, ref, entry.value),
                              onEdit: () => _editFavorite(entry.value),
                              onToggleFavorite: () => ref
                                  .read(historyProvider.notifier)
                                  .removeFavorite(entry.value),
                            ),
                          ),
                    const Divider(height: 24, indent: 16, endIndent: 16),
                    _SectionLabel(
                      icon: Icons.history_rounded,
                      title: 'Recent history',
                      subtitle: history.isEmpty
                          ? 'Generate a kingdom to add it here.'
                          : 'Newest first, up to 10 recent kingdoms.',
                    ),
                    if (history.isEmpty)
                      const _SectionEmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        message: 'No recent kingdoms yet.',
                      )
                    else
                      ...history.asMap().entries.map(
                            (entry) => _HistoryTile(
                              result: entry.value,
                              index: entry.key,
                              isFavorite: state.isFavorite(entry.value),
                              onTap: () =>
                                  _openResult(context, ref, entry.value),
                              onToggleFavorite: () => ref
                                  .read(historyProvider.notifier)
                                  .toggleFavorite(entry.value),
                            ),
                          ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editFavorite(SetupResult result) async {
    var name = result.savedName;
    var notes = result.savedNotes;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Edit saved kingdom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                initialValue: name,
                maxLength: 80,
                onChanged: (value) => name = value,
                decoration: const InputDecoration(labelText: 'Name')),
            TextFormField(
                initialValue: notes,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                onChanged: (value) => notes = value,
                decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (!mounted || save != true) return;
    await ref.read(historyProvider.notifier).editFavorite(result, name, notes);
  }

  Future<void> _exportBackup(List<SetupResult> favorites) async {
    final backup = encodeKingdomBackup(favorites);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Saved kingdoms backup'),
        content:
            SizedBox(width: 460, child: SelectableText(backup, maxLines: 8)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: backup));
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Clipboard unavailable. Select the backup text to copy it.')));
              }
            },
            child: const Text('Copy backup'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    var input = '';
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Restore saved kingdoms'),
        content: TextField(
          minLines: 3,
          maxLines: 8,
          onChanged: (value) => input = value,
          decoration: const InputDecoration(labelText: 'Paste backup JSON'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, input),
              child: const Text('Restore')),
        ],
      ),
    );
    if (!mounted || text == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final catalogue = await ref.read(allCardsProvider.future);
      if (!mounted) return;
      final boards = decodeKingdomBackup(text, catalogue);
      if (await ref.read(historyProvider.notifier).mergeFavorites(boards) &&
          mounted) {
        messenger.showSnackBar(const SnackBar(
            content:
                Text('Backup restored. Existing saved kingdoms were kept.')));
      }
    } on FormatException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not restore the saved kingdoms.')));
      }
    }
  }

  void _openResult(BuildContext context, WidgetRef ref, SetupResult result) {
    try {
      restoreKingdom(ref, result);
    } catch (error) {
      final message = switch (error) {
        SetupException(:final message) => message,
        FormatException(:final message) => message.toString(),
        _ => 'Could not open this saved kingdom.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    final navigator = Navigator.of(context);
    navigator.pop();
    final onOpenResults = widget.onOpenResults;
    if (onOpenResults != null) {
      onOpenResults();
    } else {
      navigator.push(buildResultsRoute());
    }
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear recent history?'),
            content: const Text(
              'This removes recent kingdoms from the library, but saved presets will stay available.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Clear history'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldClear || !context.mounted) return;

    final snapshot = ref.read(historyProvider).history;
    final cleared = await ref.read(historyProvider.notifier).clearHistory();
    if (!context.mounted || !cleared) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Recent history cleared. Saved presets were kept.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref.read(historyProvider.notifier).restoreHistory(snapshot);
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  final SetupResult result;
  final int index;
  final bool isFavorite;
  final IconData? leadingIcon;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;

  const _HistoryTile({
    required this.result,
    required this.index,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.onEdit,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expansions = result.kingdomCards.map((c) => c.expansion).toSet();
    final age = _formatAge(result.generatedAt);
    final primary = result.primaryArchetype;
    final pack = ref.watch(activeTranslationPackProvider).valueOrNull;
    final names = result.kingdomCards
        .map((card) => pack?.lookup(card.id)?.name ?? card.name)
        .join(', ');

    return Semantics(
      label:
          '${result.savedName.isEmpty ? 'Kingdom ${index + 1}' : result.savedName}, generated $age. $names',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: leadingIcon != null
                    ? Icon(
                        leadingIcon,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.savedName.isNotEmpty)
                      Text(result.savedName,
                          style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      names,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.savedNotes.isNotEmpty)
                      Text(result.savedNotes,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                            child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: expansions
                              .take(4)
                              .map((e) => ExpansionBadge(
                                    expansion: e,
                                    fontSize: 11,
                                  ))
                              .toList(),
                        )),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            primary != null
                                ? '${primary.headline} · $age'
                                : age,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                    tooltip: 'Edit saved kingdom',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit),
              IconButton(
                tooltip: isFavorite ? 'Delete saved preset' : 'Save preset',
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  size: 20,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SectionEmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_rounded,
                size: 48, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No saved presets or history yet.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate a kingdom, then star it to keep it locally.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
            ),
          ],
        ),
      );
}
