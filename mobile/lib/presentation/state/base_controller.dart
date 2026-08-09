import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/error/failure.dart';
import '../../data/local/data_event_bus.dart';

/// Lifecycle of a screen's data.
enum ViewStatus {
  /// Nothing requested yet.
  idle,

  /// First load in flight — show a skeleton.
  loading,

  /// Reloading while data is already on screen — keep the content, show a
  /// subtle indicator.
  refreshing,

  /// Data is present.
  ready,

  /// Loaded successfully but there is nothing to show.
  empty,

  /// Loading failed; [BaseController.errorMessage] explains why.
  error,
}

/// Shared plumbing for every screen controller.
///
/// Handles the load/refresh/error state machine, guards `notifyListeners`
/// after disposal, and wires controllers to the data change bus so a write on
/// one screen refreshes the others.
abstract class BaseController extends ChangeNotifier {
  ViewStatus _status = ViewStatus.idle;
  String? _errorMessage;
  bool _busy = false;
  bool _disposed = false;
  final List<StreamSubscription<DataEvent>> _subscriptions =
      <StreamSubscription<DataEvent>>[];

  ViewStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// True while a user-triggered action (save, delete) is running. Distinct
  /// from [isLoading] so buttons can show a spinner without blanking the page.
  bool get isBusy => _busy;

  bool get isLoading => _status == ViewStatus.loading;
  bool get isRefreshing => _status == ViewStatus.refreshing;
  bool get hasError => _status == ViewStatus.error;
  bool get isEmpty => _status == ViewStatus.empty;
  bool get isReady => _status == ViewStatus.ready || _status == ViewStatus.empty;
  bool get isDisposed => _disposed;

  /// Loads the screen's data. Implementations should be idempotent.
  ///
  /// [refreshing] keeps existing content on screen instead of showing the
  /// first-load skeleton.
  Future<void> load({bool refreshing = false});

  /// Re-runs [load] keeping current content visible.
  Future<void> refresh() => load(refreshing: true);

  /// Runs a load operation, mapping exceptions to [ViewStatus.error].
  ///
  /// [isEmptyResult] lets the caller distinguish "loaded, nothing to show" from
  /// "loaded with content" so screens can render a proper empty state.
  @protected
  Future<void> guardLoad(
    Future<void> Function() action, {
    bool refreshing = false,
    bool Function()? isEmptyResult,
  }) async {
    if (_disposed) return;
    _setStatus(
      refreshing && _status != ViewStatus.idle
          ? ViewStatus.refreshing
          : ViewStatus.loading,
      clearError: true,
    );
    try {
      await action();
      if (_disposed) return;
      final bool empty = isEmptyResult?.call() ?? false;
      _setStatus(empty ? ViewStatus.empty : ViewStatus.ready);
    } catch (error, stack) {
      if (_disposed) return;
      _reportError(error, stack);
      _errorMessage = describeFailure(error);
      _setStatus(ViewStatus.error);
    }
  }

  /// Runs a user action, returning `null` on failure.
  ///
  /// Sets [isBusy] for the duration and stores the message in [errorMessage]
  /// without destroying the content already on screen.
  @protected
  Future<T?> guardAction<T>(Future<T> Function() action) async {
    if (_disposed) return null;
    _busy = true;
    _errorMessage = null;
    safeNotify();
    try {
      final T result = await action();
      return result;
    } catch (error, stack) {
      if (!_disposed) {
        _reportError(error, stack);
        _errorMessage = describeFailure(error);
      }
      return null;
    } finally {
      _busy = false;
      safeNotify();
    }
  }

  /// Subscribes to data changes; the subscription is cancelled on dispose.
  @protected
  void listenTo(DataEventBus bus, Set<DataEntity> entities) {
    _subscriptions.add(
      bus.listen(entities, (DataEvent event) => onDataChanged(event)),
    );
  }

  /// Default reaction to an external write: reload quietly.
  @protected
  void onDataChanged(DataEvent event) {
    if (_disposed) return;
    unawaited(refresh());
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    safeNotify();
  }

  /// `notifyListeners` that is safe to call after dispose (async callbacks
  /// frequently land after a screen is popped).
  @protected
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _setStatus(ViewStatus value, {bool clearError = false}) {
    if (clearError) _errorMessage = null;
    _status = value;
    safeNotify();
  }

  void _reportError(Object error, StackTrace stack) {
    if (error is AppFailure) {
      debugPrint('[${runtimeType.toString()}] ${error.toString()}');
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'edu_manager',
        context: ErrorDescription('in $runtimeType'),
      ),
    );
  }

  /// Converts any thrown object into a message safe to show a teacher.
  static String describeFailure(Object error) {
    if (error is AppFailure) return error.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    for (final StreamSubscription<DataEvent> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
