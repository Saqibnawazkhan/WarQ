import 'dart:async';

/// Entities that can change at runtime.
enum DataEntity {
  users,
  organizations,
  classes,
  students,
  enrollments,
  attendance,
  assessments,
  marks,
  gradeScales,
  notifications,
  invitations,
  activity,
  messages,
}

/// A single mutation broadcast to interested controllers.
class DataEvent {
  const DataEvent(this.entity, {this.id, this.classId});

  final DataEntity entity;
  final String? id;
  final String? classId;

  @override
  String toString() => 'DataEvent(${entity.name}, id: $id)';
}

/// Lightweight pub/sub used to keep independent screens in sync.
///
/// Repositories emit after every write; controllers subscribe to the entities
/// they render and reload. This avoids a single god-provider while still
/// guaranteeing that, for example, adding a student refreshes both the class
/// screen and the dashboard counters.
class DataEventBus {
  final StreamController<DataEvent> _controller =
      StreamController<DataEvent>.broadcast();

  Stream<DataEvent> get stream => _controller.stream;

  void emit(DataEntity entity, {String? id, String? classId}) {
    if (_controller.isClosed) return;
    _controller.add(DataEvent(entity, id: id, classId: classId));
  }

  void emitAll(Iterable<DataEntity> entities) {
    for (final DataEntity entity in entities) {
      emit(entity);
    }
  }

  /// Subscribe to a subset of entities.
  StreamSubscription<DataEvent> listen(
    Set<DataEntity> entities,
    void Function(DataEvent event) onEvent,
  ) {
    return stream
        .where((DataEvent event) => entities.contains(event.entity))
        .listen(onEvent);
  }

  Future<void> dispose() => _controller.close();
}
