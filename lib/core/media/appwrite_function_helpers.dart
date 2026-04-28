import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';
import 'package:WhatsUnity/core/config/runtime_env.dart';

import 'media_upload_exception.dart';

/// Sync Appwrite Function execution with JSON body/response.
Future<Map<String, dynamic>> invokeAppwriteFunctionJson({
  required Functions functions,
  required String functionId,
  required Map<String, dynamic> payload,
}) async {
  try {
    final execution = await functions.createExecution(
      functionId: functionId,
      body: jsonEncode(payload),
      xasync: false,
    );
    return _parseExecutionResponse(execution);
  } on AppwriteException catch (e) {
    if (e.code == 404 || e.type == 'function_not_found') {
      throw MediaUploadException(
        'Appwrite function not found (id=$functionId). '
        'Use the function \$id from the console, not its name. '
        'Set APPWRITE_FUNCTION_GET_R2_SIGNED_URL / APPWRITE_FUNCTION_CREATE_GUMLET_ASSET '
        'via --dart-define-from-file (or individual --dart-define).',
        e,
      );
    }
    if (e.code == 401 ||
        e.type == 'user_unauthorized' ||
        (e.message ?? '').contains('execute')) {
      throw MediaUploadException(
        'Cannot execute Appwrite function (id=$functionId): missing execute permission. '
        'In Console → Functions → Settings, add execute access for signed-in users (e.g. "Users"), '
        'or set "execute": ["users"] in appwrite.config.json and run appwrite push functions. '
        'Ensure the app user has an active session.',
        e,
      );
    }
    rethrow;
  }
}

String _executionFailureDetail(dynamic execution) {
  final parts = <String>[];

  final errors = execution.errors;
  if (errors is List && errors.isNotEmpty) {
    parts.add('errors=${errors.join(', ')}');
  } else if (errors is String && errors.isNotEmpty) {
    parts.add('errors=$errors');
  }

  final logs = (execution as dynamic).logs;
  if (logs is String && logs.isNotEmpty) {
    final trimmed =
        logs.length > 2500 ? '${logs.substring(0, 2500)}…' : logs;
    parts.add('logs=$trimmed');
  }

  final code = execution.responseStatusCode;
  if (code != null) {
    parts.add('responseHttp=$code');
  }

  final body = execution.responseBody;
  if (body is String && body.isNotEmpty) {
    final t =
        body.length > 1200 ? '${body.substring(0, 1200)}…' : body;
    parts.add('responseBody=$t');
  }

  return parts.isEmpty ? '(no execution detail)' : parts.join(' | ');
}

Map<String, dynamic> _parseExecutionResponse(dynamic execution) {
  if (execution.status == ExecutionStatus.failed) {
    throw MediaUploadException(
      'Appwrite function failed: ${_executionFailureDetail(execution)}',
    );
  }

  if (execution.status != ExecutionStatus.completed) {
    throw MediaUploadException(
      'Appwrite function not completed (status=${execution.status.value})',
    );
  }

  if (execution.responseStatusCode >= 400) {
    throw MediaUploadException(
      'Appwrite function HTTP ${execution.responseStatusCode}: ${execution.responseBody}',
    );
  }

  final raw = execution.responseBody.trim();
  if (raw.isEmpty) {
    throw MediaUploadException('Appwrite function returned empty body');
  }

  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw MediaUploadException('Appwrite function returned non-object JSON');
  }
  return Map<String, dynamic>.from(decoded);
}

/// Resolve function **$id** from a compile-time define or [defaultId] (must be the Appwrite function document id).
String resolveFunctionId(String envKey, String defaultId) {
  final v = RuntimeEnv.functionOverrideForEnvKey(envKey);
  if (v != null && v.isNotEmpty) return v.trim();
  return defaultId;
}

String? pickString(Map<String, dynamic> map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

/// Gumlet often nests playback under [output].
String? pickPlaybackUrl(Map<String, dynamic> map) {
  final direct = pickString(map, ['playback_url', 'playbackUrl', 'url']);
  if (direct != null) return direct;
  final out = map['output'];
  if (out is Map) {
    final nested = Map<String, dynamic>.from(out);
    return pickString(nested, ['playback_url', 'playbackUrl', 'hls', 'url']);
  }
  return null;
}
