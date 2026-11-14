import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'action_queue.dart';

/// Durable queue so a post written on the subway still publishes once the
/// device reconnects — or after the process was killed.
class HiveActionQueue implements ActionQueue {
  HiveActionQueue(this.box);
  final Box<dynamic> box;
  static const maxActions = 100;

  static Future<HiveActionQueue> open([String name = 'nexus_queue']) async =>
      HiveActionQueue(await Hive.openBox<dynamic>(name));

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
    await box.put(action.id, jsonEncode(action.toJson()));
    if (box.length > maxActions) {
      final ids = box.keys.map((k) => '$k').toList();
      for (final id in ids.take(box.length - maxActions)) {
        await box.delete(id);
      }
    }
    return action;
  }

  @override
  Future<List<QueuedAction>> all() async {
    final items = <QueuedAction>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! String) continue;
      try {
        items.add(
          QueuedAction.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        await box.delete(key);
      }
    }
    items.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return items;
  }

  @override
  Future<int> length() async => box.length;

  @override
  Future<void> remove(String id) async => box.delete(id);

  @override
  Future<void> clear() async => box.clear();
}
