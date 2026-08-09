/// Domain-level error type.
///
/// The data layer never throws raw exceptions across its boundary; it converts
/// them into an [AppFailure] so the presentation layer can render a friendly
/// message without knowing whether the source was local storage or (later) an
/// HTTP API.
class AppFailure implements Exception {
  const AppFailure(
    this.message, {
    this.code = FailureCode.unknown,
    this.details,
  });

  const AppFailure.notFound(String what)
      : message = '$what could not be found.',
        code = FailureCode.notFound,
        details = null;

  const AppFailure.validation(this.message)
      : code = FailureCode.validation,
        details = null;

  const AppFailure.unauthorized([this.message = 'You are not allowed to do that.'])
      : code = FailureCode.unauthorized,
        details = null;

  const AppFailure.conflict(this.message)
      : code = FailureCode.conflict,
        details = null;

  const AppFailure.storage(this.message, {this.details})
      : code = FailureCode.storage;

  final String message;
  final FailureCode code;
  final Object? details;

  @override
  String toString() => 'AppFailure(${code.name}): $message';
}

enum FailureCode {
  unknown,
  notFound,
  validation,
  unauthorized,
  conflict,
  storage,
  network,
}
