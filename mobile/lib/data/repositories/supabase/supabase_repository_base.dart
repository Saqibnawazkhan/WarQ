import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../local/data_event_bus.dart';

/// Shared plumbing for every Supabase-backed repository.
///
/// Two jobs, both of which every repository would otherwise repeat.
///
/// The first is turning transport errors into [AppFailure]. The data layer
/// promises the rest of the app that nothing else crosses its boundary, so a
/// dropped connection and a row-level-security refusal have to arrive as the
/// same kind of object, distinguished by [FailureCode] rather than by type.
///
/// The second is announcing writes on the [DataEventBus]. The local
/// repositories emit after every mutation and the controllers rely on it to
/// keep independent screens in step; swapping the backend must not quietly
/// remove that. So the guards below take the entities a write touches and emit
/// once it has actually succeeded.
abstract class SupabaseRepositoryBase {
  SupabaseRepositoryBase(this.client, this.bus);

  final SupabaseClient client;
  final DataEventBus bus;

  /// The signed-in user, or null when the session has gone.
  String? get currentUserId => client.auth.currentUser?.id;

  /// The signed-in user, or a failure. Used by writes that cannot be attributed
  /// to nobody; the database would refuse them anyway, but failing here gives a
  /// better message than a row-level-security rejection.
  String get requireUserId {
    final String? id = currentUserId;
    if (id == null) {
      throw const AppFailure.unauthorized('Please sign in again.');
    }
    return id;
  }

  /// Runs a read and converts anything thrown into an [AppFailure].
  Future<T> read<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw asFailure(error);
    }
  }

  /// Runs a write, converts failures, then announces the change.
  ///
  /// [touches] is emitted only after [body] returns, so a controller never
  /// reloads in response to a write that did not happen.
  Future<T> write<T>(
    Future<T> Function() body, {
    required Set<DataEntity> touches,
    String? id,
    String? classId,
  }) async {
    final T result;
    try {
      result = await body();
    } catch (error) {
      throw asFailure(error);
    }

    for (final DataEntity entity in touches) {
      bus.emit(entity, id: id, classId: classId);
    }
    return result;
  }

  /// Translates a Supabase/Postgrest error into the app's own failure type.
  ///
  /// The Postgres codes worth naming are the ones the schema can actually
  /// produce. Everything else keeps its server message, because the database
  /// functions raise messages written for teachers to read
  /// ("A register cannot be taken for a future date.") and rewording them here
  /// would lose that.
  AppFailure asFailure(Object error) {
    if (error is AppFailure) return error;

    if (error is PostgrestException) {
      return switch (error.code) {
        // raise exception in a plpgsql function. The message is deliberate.
        'P0001' => AppFailure.validation(error.message),
        // Row-level security refused, or the grant is missing.
        '42501' => AppFailure.unauthorized(error.message),
        // Unique violation: a duplicate roll number, a second register for the
        // same class and day, a re-used invitation.
        '23505' => AppFailure.conflict(_friendlyConflict(error)),
        // Foreign key violation: pointing at something that is not there.
        '23503' => const AppFailure.validation(
            'That record refers to something that no longer exists. '
            'Please refresh and try again.',
          ),
        // Check constraint: the value itself is not allowed.
        '23514' => const AppFailure.validation(
            'That value is not allowed. Please check the form and try again.',
          ),
        // Not-null violation.
        '23502' => const AppFailure.validation('A required field is missing.'),
        // .single() matched no rows.
        'PGRST116' => const AppFailure.notFound('That record'),
        // The schema cache does not know the function or column. A deployment
        // problem rather than anything the person using the app did.
        'PGRST202' || 'PGRST204' => AppFailure.storage(
            'The app is out of step with the server. Please update the app.',
            details: error.message,
          ),
        _ => AppFailure.storage(error.message, details: error.code),
      };
    }

    if (error is AuthException) {
      return AppFailure.unauthorized(error.message);
    }

    if (error is SocketException || error is TimeoutException) {
      return const AppFailure(
        'No connection. Check your internet and try again.',
        code: FailureCode.network,
      );
    }

    return AppFailure.storage('Something went wrong.', details: error);
  }

  /// Unique-violation messages name the constraint, which is meaningless to a
  /// teacher. The ones the app can actually trip get said properly.
  String _friendlyConflict(PostgrestException error) {
    final String text = '${error.message} ${error.details ?? ''}'.toLowerCase();
    if (text.contains('roll')) {
      return 'Another student in this class already has that roll number.';
    }
    if (text.contains('attendance_sessions')) {
      return 'A register has already been taken for this class on that date.';
    }
    if (text.contains('invitation')) {
      return 'That email address has already been invited.';
    }
    if (text.contains('class_students')) {
      return 'That student is already enrolled in this class.';
    }
    return 'That already exists.';
  }
}
