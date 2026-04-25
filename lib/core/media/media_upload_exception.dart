/// Thrown when hybrid storage upload or Appwrite Function orchestration fails.
class MediaUploadException implements Exception {
  MediaUploadException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause != null ? 'MediaUploadException: $message ($cause)' : 'MediaUploadException: $message';
}
