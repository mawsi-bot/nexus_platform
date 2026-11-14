import 'package:uuid/uuid.dart';

import '../../domain/repository.dart';

/// One write that happened while the device had no usable connection.
class QueuedAction {
  const QueuedAction({
    required this.id,
    required this.path,
    required this.body,
    required this.queuedAt,
    this.method = 'POST',
    this.label = '',
  });
  final String id;
  final String path;
  final Map<String, dynamic> body;
  final DateTime queuedAt;
  final String method;
  final String label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'body': body,
    'method': method,
    'label': label,
    'queued_at': queuedAt.toUtc().toIso8601String(),
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    id: '${json['id'] ?? ''}',
    path: '${json['path'] ?? ''}',
    body: Map<String, dynamic>.from((json['body'] as Map?) ?? const {}),
    method: '${json['method'] ?? 'POST'}',
    label: '${json['label'] ?? ''}',
    queuedAt:
        DateTime.tryParse('${json['queued_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

abstract interface class ActionQueue {
  Future<QueuedAction> add({
    required String path,
    required Map<String, dynamic> body,
    String method,
    String label,
  });
  Future<List<QueuedAction>> all();
  Future<int> length();
  Future<void> remove(String id);
  Future<void> clear();
}

class MemoryActionQueue implements ActionQueue {
  final List<QueuedAction> _items = [];
  int get count => _items.length;

  @override
  Future<QueuedAction> add({
    required String path,
    required Map<String, dynamic> body,
    String method = 'POST',
    String label = '',
  }) async {
    final action = QueuedAction(
      id: const Uuid().v4(),
      path: path,
      body: body,
      method: method,
      label: label,
      queuedAt: DateTime.now(),
    );
    _items.add(action);
    return action;
  }

  @override
  Future<List<QueuedAction>> all() async => List.unmodifiable(_items);

  @override
  Future<int> length() async => _items.length;

  @override
  Future<void> remove(String id) async => _items.removeWhere((a) => a.id == id);

  @override
  Future<void> clear() async => _items.clear();
}

/// Replays queued writes oldest-first. A failure stops the pump so ordering is
/// preserved and nothing is silently dropped.
class ActionQueuePump {
  ActionQueuePump({required this.queue, required this.repo});
  final ActionQueue queue;
  final NexusRepository repo;

  Future<int> drain() async {
    var sent = 0;
    for (final action in await queue.all()) {
      try {
        await repo.send(action.path, action.body, method: action.method);
        await queue.remove(action.id);
        sent++;
      } catch (_) {
        break;
      }
    }
    return sent;
  }
}
