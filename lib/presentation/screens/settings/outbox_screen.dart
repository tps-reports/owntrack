import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:share_plus/share_plus.dart';

/// Recovery controls operate on explicitly selected durable message identities.
class OutboxScreen extends ConsumerStatefulWidget {
  const OutboxScreen({super.key, this.share});

  final Future<ShareResult> Function(ShareParams)? share;

  @override
  ConsumerState<OutboxScreen> createState() => _OutboxScreenState();
}

class _OutboxScreenState extends ConsumerState<OutboxScreen> {
  late final MessageQueueRepository _queue;
  late final MessageProcessor _processor;
  StreamSubscription<int>? _subscription;
  List<QueuedMessage> _messages = [];
  final Set<int> _selected = {};
  String? _destination;
  String? _error;
  String? _notice;
  bool _loading = false;
  bool _busy = false;
  bool _confirming = false;

  bool get _available => !_loading && !_busy;

  @override
  void initState() {
    super.initState();
    _queue = ref.read(messageQueueRepositoryProvider);
    _processor = ref.read(messageProcessorProvider);
    _messages = _queue.getAllMessages();
    _subscription = _queue.changes.listen(
      (_) => _updateSnapshot(),
      onError: (Object error, StackTrace stack) {
        _showFailure('refresh', error, stack);
      },
    );
    unawaited(_refresh());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _updateSnapshot() {
    if (!mounted) return;
    setState(() {
      _messages = _queue.getAllMessages();
      final remaining = _messages.map((message) => message.id).toSet();
      _selected.retainAll(remaining);
    });
  }

  void _showFailure(String operation, Object error, StackTrace stack) {
    AppLogger.e('Outbox $operation failed.', error.runtimeType, stack);
    if (!mounted) return;
    setState(() {
      _error =
          'Unable to $operation. Your queued messages are retained. '
          'Try again.';
      _notice = null;
    });
  }

  Future<void> _refresh() async {
    if (!_available) return;
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      await _queue.refresh();
      final destination = await _processor.currentDestination();
      if (!mounted) return;
      setState(() => _destination = destination);
      _updateSnapshot();
    } catch (error, stack) {
      if (mounted) setState(() => _destination = null);
      _showFailure('refresh', error, stack);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          scrollable: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _beginAction({bool confirming = false}) {
    setState(() {
      _busy = true;
      _confirming = confirming;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _export(BuildContext buttonContext) async {
    if (!_available || _selected.isEmpty) return;
    final ids = Set<int>.of(_selected);
    final box = buttonContext.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    _beginAction(confirming: true);
    try {
      final confirmed = await _confirm(
        title: 'Export ${ids.length} selected messages?',
        message:
            'This file contains private location history and device '
            'identifiers. Choose a trusted destination and keep the file '
            'private. Exporting does not remove messages from the outbox.',
        action: 'Continue to export',
      );
      if (mounted) setState(() => _confirming = false);
      if (!confirmed || !mounted) return;
      final data = await _queue.exportMessages(ids);
      if (!mounted) return;
      final name =
          'owntrack-outbox-${DateTime.now().toUtc().millisecondsSinceEpoch}.json';
      final result = await (widget.share ?? SharePlus.instance.share)(
        ShareParams(
          title: 'OwnTracks outbox export',
          files: [
            XFile.fromData(utf8.encode(data), mimeType: 'application/json'),
          ],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
      if (!mounted) return;
      setState(() {
        _notice = result.status == ShareResultStatus.dismissed
            ? 'Export cancelled. Messages were not discarded.'
            : 'Export handed to your device. Check the chosen destination '
                  'before discarding messages.';
      });
    } catch (error, stack) {
      _showFailure('export', error, stack);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  Future<void> _discard() async {
    if (!_available || _selected.isEmpty) return;
    final ids = Set<int>.of(_selected);
    _beginAction(confirming: true);
    try {
      final confirmed = await _confirm(
        title: 'Discard ${ids.length} selected messages?',
        message:
            'This permanently removes the selected messages from this '
            'outbox. Export a copy first if you need to keep them. '
            'Deliveries already in progress cannot be recalled.',
        action: 'Discard permanently',
      );
      if (mounted) setState(() => _confirming = false);
      if (!confirmed || !mounted) return;
      final removed = await _queue.discardMessages(ids);
      if (!mounted) return;
      _updateSnapshot();
      setState(() {
        _notice =
            '$removed ${removed == 1 ? 'message' : 'messages'} discarded.';
      });
    } catch (error, stack) {
      _showFailure('discard', error, stack);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  Future<void> _retry() async {
    if (!_available) return;
    _beginAction();
    try {
      await _processor.retryDelivery();
      await _queue.refresh();
      final destination = await _processor.currentDestination();
      if (!mounted) return;
      _updateSnapshot();
      setState(() {
        _destination = destination;
        _error = _processor.lastError;
        _notice = _error == null
            ? 'Delivery retry finished. ${_messages.length} '
                  '${_messages.length == 1 ? 'message remains' : 'messages remain'}.'
            : null;
      });
    } catch (error, stack) {
      _showFailure('retry delivery', error, stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(int seconds) {
    try {
      final time = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
      ).toLocal();
      final localizations = MaterialLocalizations.of(context);
      return '${localizations.formatFullDate(time)}, '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
    } on ArgumentError {
      return 'Invalid stored time';
    }
  }

  String _status(QueuedMessage message) {
    if (message.destination == null) {
      return 'Legacy message — export to recover its stored data. '
          'Its original connection is unknown, so it will not be sent.';
    }
    if (_destination == null) return 'Refresh to check the connection.';
    if (message.destination != _destination) {
      return 'Restore the original connection and encryption settings to '
          'deliver this message, or export a copy.';
    }
    if (message.retryAt > DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      return 'Waiting to retry after ${_time(message.retryAt)}.';
    }
    return 'Waiting for delivery to the current connection.';
  }

  @override
  Widget build(BuildContext context) {
    final canRetry =
        _available &&
        _destination != null &&
        _messages.any((message) => message.destination == _destination);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outbox'),
        actions: [
          IconButton(
            tooltip: 'Refresh outbox',
            onPressed: _available ? _refresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading || (_busy && !_confirming)) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating outbox',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _messages.isEmpty
                        ? 'No queued messages'
                        : '${_messages.length} queued '
                              '${_messages.length == 1 ? 'message' : 'messages'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Messages stay here until the server acknowledges them '
                    'or you discard them. Messages for another connection '
                    'are kept until you restore its settings.',
                  ),
                  if (_error != null || _notice != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error ?? _notice!,
                        style: TextStyle(
                          color: _error == null
                              ? null
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: canRetry ? _retry : null,
                        icon: const Icon(Icons.sync),
                        label: const Text('Retry delivery'),
                      ),
                      Builder(
                        builder: (context) => OutlinedButton.icon(
                          onPressed: _available && _selected.isNotEmpty
                              ? () => _export(context)
                              : null,
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Export selected'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _available && _selected.isNotEmpty
                            ? _discard
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Discard selected'),
                      ),
                    ],
                  ),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${_selected.length} selected'),
                    TextButton(
                      onPressed: _available
                          ? () {
                              setState(() {
                                if (_selected.length == _messages.length) {
                                  _selected.clear();
                                } else {
                                  _selected.addAll(
                                    _messages.map((message) => message.id),
                                  );
                                }
                              });
                            }
                          : null,
                      child: Text(
                        _selected.length == _messages.length
                            ? 'Clear selection'
                            : 'Select all',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            }
            final message = _messages[index - 1];
            return CheckboxListTile(
              key: ValueKey('outbox-message-${message.id}'),
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(message.id),
              onChanged: _available
                  ? (selected) => setState(() {
                      if (selected == true) {
                        _selected.add(message.id);
                      } else {
                        _selected.remove(message.id);
                      }
                    })
                  : null,
              title: Text('Message ${message.id}'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Queued ${_time(message.timestamp)}'),
                    Text('Retry attempts: ${message.retryCount}'),
                    const SizedBox(height: 4),
                    Text(_status(message)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
