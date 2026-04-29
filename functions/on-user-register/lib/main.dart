// Appwrite Cloud Function (Dart) — on_user_register
//
// Trigger: users.*.update.prefs
// Runtime: Dart 3.x (open runtimes)
//
// Required environment variables (Console → Functions → Variables):
// - APPWRITE_API_KEY (server key with databases.* scope; often injected for functions)
// - APPWRITE_DATABASE_ID (your Databases API database id, e.g. from .env / APPWRITE_SCHEMA.md)
//
// Standard function env (when available):
// - APPWRITE_FUNCTION_ENDPOINT / APPWRITE_ENDPOINT
// - APPWRITE_FUNCTION_PROJECT_ID / APPWRITE_PROJECT_ID
//
// Deploy: from project root, use Appwrite CLI (`appwrite init functions`, `appwrite push functions`)
// per https://appwrite.io/docs/tooling/command-line/functions
//
// Client: after account.create(), call account.updatePrefs() with the custom keys
// (avatar_url, full_name, ownerType, phoneNumber, role_id, compound_id, building_num, apartment_num).

import 'dart:convert';
import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart'
    show AppwriteException, Client, Databases, ID, Query;

// APPWRITE_SCHEMA.md + tools/provision_spec.json
const _kColProfiles = 'profiles';
const _kColUserRoles = 'user_roles';
const _kColUserApartments = 'user_apartments';
const _kColBuildings = 'buildings';
const _kColChannels = 'channels';
const _kColCompounds = 'compounds';

// ---------------------------------------------------------------------------
// Open Runtimes: request body (supports bodyRaw, bodyText, bodyJson, body)
// ---------------------------------------------------------------------------

Object? _readBodyRaw(dynamic context) {
  final dynamic req = _req(context);
  if (req == null) return null;
  try {
    final br = req.bodyRaw;
    if (br != null && '$br'.trim().isNotEmpty) return br;
  } catch (_) {}
  try {
    final bt = req.bodyText;
    if (bt != null && '$bt'.trim().isNotEmpty) return bt;
  } catch (_) {}
  return null;
}

Object? _readBodyJson(dynamic context) {
  final dynamic req = _req(context);
  if (req == null) return null;
  try {
    final bj = req.bodyJson;
    if (bj != null) return bj;
  } catch (_) {}
  try {
    final b = req.body;
    if (b != null) return b;
  } catch (_) {}
  return null;
}

dynamic _req(dynamic context) {
  try {
    return context.req;
  } catch (_) {
    return null;
  }
}

Map<String, String> _headerMap(dynamic context) {
  final req = _req(context);
  if (req == null) return {};
  try {
    final h = req.headers;
    if (h is! Map) return {};
    return Map<String, String>.fromEntries(
      h.entries.map(
        (e) => MapEntry(e.key.toString().toLowerCase(), e.value.toString()),
      ),
    );
  } catch (_) {
    return {};
  }
}

String? _env(String key) {
  final v = Platform.environment[key];
  if (v == null || v.isEmpty) return null;
  return v;
}

Map<String, dynamic> _parseRoot(dynamic context) {
  // Prefer raw JSON string; fall back to parsed body.
  final raw = _readBodyRaw(context);
  if (raw is String && raw.trim().isNotEmpty) {
    final decoded = json.decode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  final j = _readBodyJson(context);
  if (j is Map) {
    return Map<String, dynamic>.from(j);
  }
  return <String, dynamic>{};
}

/// Webhook / event bodies may wrap the payload under "payload" or "data".
Map<String, dynamic> _unwrapEvent(Map<String, dynamic> root) {
  for (final key in const ['payload', 'data', 'event']) {
    if (root[key] is Map) {
      return Map<String, dynamic>.from(root[key]! as Map);
    }
  }
  return root;
}

Map<String, dynamic> _prefsFrom(Map<String, dynamic> root) {
  Map<String, dynamic>? p;

  // Top-level prefs
  if (root['prefs'] is Map) {
    p = Map<String, dynamic>.from(root['prefs']! as Map);
  } else if (root['prefs'] is String) {
    try {
      final d = json.decode(root['prefs'] as String);
      if (d is Map) p = Map<String, dynamic>.from(d);
    } catch (_) {}
  }

  // user.prefs
  if (p == null && root['user'] is Map) {
    final u = root['user']! as Map;
    if (u['prefs'] is Map) {
      p = Map<String, dynamic>.from(u['prefs']! as Map);
    } else if (u['prefs'] is String) {
      try {
        final d = json.decode(u['prefs'] as String);
        if (d is Map) p = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
  }

  return p ?? <String, dynamic>{};
}

String? _s(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final t = v.toString().trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}

int? _intPref(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final p = int.tryParse(v.toString().trim());
    if (p != null) return p;
  }
  return null;
}

bool _isBlank(String? s) => s == null || s.trim().isEmpty;

// ---------------------------------------------------------------------------
// Databases
// ---------------------------------------------------------------------------

Client _buildClient(Map<String, String> headers) {
  final endpoint = _env('APPWRITE_FUNCTION_ENDPOINT') ??
      _env('APPWRITE_ENDPOINT') ??
      'https://cloud.appwrite.io/v1';
  var project =
      _env('APPWRITE_FUNCTION_PROJECT_ID') ?? _env('APPWRITE_PROJECT_ID');
  project ??= headers['x-appwrite-project'];
  if (project == null || project.isEmpty) {
    throw StateError(
        'Missing project id: set APPWRITE_FUNCTION_PROJECT_ID or x-appwrite-project');
  }
  final key = _env('APPWRITE_API_KEY') ?? _env('APPWRITE_FUNCTION_API_KEY');
  if (key == null || key.isEmpty) {
    throw StateError('Missing APPWRITE_API_KEY (or APPWRITE_FUNCTION_API_KEY)');
  }
  return Client().setEndpoint(endpoint).setProject(project).setKey(key);
}

String _requireDatabaseId() {
  final id =
      _env('APPWRITE_DATABASE_ID') ?? _env('APPWRITE_FUNCTION_DATABASE_ID');
  if (id == null || id.isEmpty) {
    throw StateError(
        'Set APPWRITE_DATABASE_ID for this function (e.g. same as Flutter .env).');
  }
  return id;
}

Future<void> _createOrUpdateProfile(
  Databases db,
  String databaseId,
  String userId,
  Map<String, dynamic> data,
) async {
  try {
    await db.createDocument(
      databaseId: databaseId,
      collectionId: _kColProfiles,
      documentId: ID.custom(userId),
      data: data,
    );
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      await db.updateDocument(
        databaseId: databaseId,
        collectionId: _kColProfiles,
        documentId: userId,
        data: data,
      );
    } else {
      rethrow;
    }
  }
}

Future<void> _createOrReplaceUserRole(
  Databases db,
  String databaseId,
  String userId,
  int roleId,
) async {
  final row = {
    'profile': userId,
    'user_id': userId,
    'role_id': roleId,
    'version': 0,
  };
  try {
    await db.createDocument(
      databaseId: databaseId,
      collectionId: _kColUserRoles,
      documentId: ID.custom(userId),
      data: row,
    );
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      await db.updateDocument(
        databaseId: databaseId,
        collectionId: _kColUserRoles,
        documentId: userId,
        data: {'role_id': roleId},
      );
    } else {
      rethrow;
    }
  }
}

Future<dynamic> main(final context) async {
  void log(String m) {
    try {
      context.log(m);
    } catch (_) {
      // ignore: avoid_print
      print(m);
    }
  }

  Map<String, Object?> ok([Map<String, Object?>? extra]) {
    return <String, Object?>{'ok': true, ...?extra};
  }

  Map<String, Object?> err(String message, [Object? st]) {
    return {
      'ok': false,
      'error': message,
      if (st != null) 'details': st.toString()
    };
  }

  try {
    final headers = _headerMap(context);
    final client = _buildClient(headers);
    final db = Databases(client);
    final databaseId = _requireDatabaseId();

    final rootRaw = _parseRoot(context);
    final root = _unwrapEvent(rootRaw);
    final prefs = _prefsFrom(root);

    // User identity: event / user object (and $id from Appwrite events)
    String? userId;
    if (root[r'$id'] != null) {
      userId = root[r'$id'].toString();
    }
    userId ??= _s(root, const ['userId', 'user_id', 'id']);
    if (userId == null && root['user'] is Map) {
      final u = root['user']! as Map;
      userId = _s(
        Map<String, dynamic>.from(u),
        const [r'$id', 'userId', 'user_id', 'id'],
      );
    }
    if (_isBlank(userId)) {
      log('on_user_register: no user id in payload');
      return _jsonRes(context, err('Missing user id'), 400);
    }
    final uid = userId!;

    var name = _s(root, const ['name', 'Name']);
    if (name == null && root['user'] is Map) {
      name = _s(
        Map<String, dynamic>.from(root['user']! as Map),
        const ['name', 'Name'],
      );
    }
    name = name?.trim();
    if (_isBlank(name)) name = 'New User';

    var email = _s(root, const ['email', 'Email']);
    if (email == null && root['user'] is Map) {
      email = _s(
        Map<String, dynamic>.from(root['user']! as Map),
        const ['email', 'Email'],
      );
    }

    // Prefs: mix root + prefs (Flutter updatePrefs)
    final merged = <String, dynamic>{...root, ...prefs};

    final avatarUrl = _s(merged, const ['avatar_url', 'avatarUrl']);
    final fullName = _s(merged, const ['full_name', 'fullName']);
    final ownerType = _s(merged, const ['ownerType', 'owner_type']);
    final phoneNumber = _s(merged, const ['phoneNumber', 'phone_number']);
    final roleId = _intPref(merged, const ['role_id', 'roleId']) ?? 1;
    final compoundId = _s(merged, const ['compound_id', 'compoundId']);
    final buildingNum = _s(merged, const ['building_num', 'buildingNum']);
    final apartmentNum = _s(merged, const ['apartment_num', 'apartmentNum']);

    log('on_user_register: user=$uid email=$email prefs_keys=${merged.keys.toList()}');

    // ---- Profile
    try {
      final display =
          (fullName != null && fullName.isNotEmpty) ? fullName : name;
      final profileData = <String, dynamic>{
        'full_name': fullName ?? '',
        'display_name': display,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (ownerType != null) 'owner_type': ownerType,
        'version': 0,
      };
      await _createOrUpdateProfile(db, databaseId, uid, profileData);
    } catch (e, st) {
      log('profile: $e\n$st');
      return _jsonRes(context, err('profile', e), 500);
    }

    // ---- Role
    try {
      await _createOrReplaceUserRole(db, databaseId, uid, roleId);
    } catch (e, st) {
      log('user_roles: $e\n$st');
      return _jsonRes(context, err('user_roles', e), 500);
    }

    // Google / incomplete signup: no residential scope
    if (_isBlank(compoundId) || _isBlank(buildingNum)) {
      log('on_user_register: skip building/channel/apartment (empty compound or building)');
      return _jsonRes(
        context,
        ok(<String, Object?>{
          'step': 'profile_and_role_only',
          'reason': 'missing_compound_or_building',
        }),
        200,
      );
    }
    final compound = compoundId!.trim();
    final bn = buildingNum!.trim();

    // ---- Building (upsert by compound + building_name; building_name = building_num string)
    String buildingDocId;
    try {
      final existing = await db.listDocuments(
        databaseId: databaseId,
        collectionId: _kColBuildings,
        queries: [
          Query.equal('compound_id', compound),
          Query.equal('building_name', bn),
          Query.isNull('deleted_at'),
          Query.limit(1),
        ],
      );
      if (existing.documents.isNotEmpty) {
        buildingDocId = existing.documents.first.$id;
      } else {
        final created = await db.createDocument(
          databaseId: databaseId,
          collectionId: _kColBuildings,
          documentId: ID.unique(),
          data: {
            'compound_id': compound,
            'building_name': bn,
            'version': 0,
          },
        );
        buildingDocId = created.$id;
      }
    } catch (e, st) {
      log('buildings: $e\n$st');
      return _jsonRes(context, err('buildings', e), 500);
    }

    // ---- Channels (idempotent upsert per building)
    // BUILDING_CHAT: create only if missing for this compound/building.
    // COMPOUND_GENERAL: also check independently for the same building_id and create only if missing.
    try {
      final buildingChatQ = await db.listDocuments(
        databaseId: databaseId,
        collectionId: _kColChannels,
        queries: [
          Query.equal('compound_id', compound),
          Query.equal('building_id', buildingDocId),
          Query.equal('type', 'BUILDING_CHAT'),
          Query.isNull('deleted_at'),
          Query.limit(1),
        ],
      );

      if (buildingChatQ.documents.isEmpty) {
        await db.createDocument(
          databaseId: databaseId,
          collectionId: _kColChannels,
          documentId: ID.unique(),
          data: {
            'compound_id': compound,
            'building_id': buildingDocId,
            'name': 'Building $bn Chat',
            'type': 'BUILDING_CHAT',
            'version': 0,
          },
        );
      }

      final compoundGeneralQ = await db.listDocuments(
        databaseId: databaseId,
        collectionId: _kColChannels,
        queries: [
          Query.equal('compound_id', compound),
          Query.equal('building_id', buildingDocId),
          Query.equal('type', 'COMPOUND_GENERAL'),
          Query.isNull('deleted_at'),
          Query.limit(1),
        ],
      );

      if (compoundGeneralQ.documents.isEmpty) {
        await db.createDocument(
          databaseId: databaseId,
          collectionId: _kColChannels,
          documentId: ID.unique(),
          data: {
            'compound_id': compound,
            'building_id': buildingDocId,
            'name': 'Building $bn General',
            'type': 'COMPOUND_GENERAL',
            'version': 0,
          },
        );
      }
    } catch (e, st) {
      log('channels: $e\n$st');
      return _jsonRes(context, err('channels', e), 500);
    }

    // ---- user_apartments (optional)
    if (apartmentNum != null && apartmentNum.isNotEmpty) {
      try {
        await db.createDocument(
          databaseId: databaseId,
          collectionId: _kColUserApartments,
          documentId: ID.unique(),
          data: {
            'profile': uid,
            'user_id': uid,
            'compound_id': compound,
            'building_num': bn,
            'apartment_num': apartmentNum,
            'version': 0,
          },
        );
      } on AppwriteException catch (e) {
        if (e.code == 409) {
          log('user_apartments: already exists, skip');
        } else {
          rethrow;
        }
      } catch (e, st) {
        log('user_apartments: $e\n$st');
        return _jsonRes(context, err('user_apartments', e), 500);
      }
    }

    return _jsonRes(
      context,
      ok(<String, Object?>{
        'userId': uid,
        'buildingId': buildingDocId,
        'step': 'complete',
      }),
      200,
    );
  } catch (e, st) {
    try {
      context.error('$e\n$st');
    } catch (_) {}
    return _jsonRes(
      context,
      err('fatal', e),
      500,
    );
  }
}

/// Normalized JSON response for Open Runtimes.
dynamic _jsonRes(dynamic context, Map<String, Object?> body, int status) {
  try {
    // Preferred: return context.res.json with status (if supported)
    return context.res.json(body, status: status);
  } catch (_) {
    try {
      return context.res.json(body);
    } catch (_) {
      // Fallback: return string body map (executor may still expect res.json)
      return body;
    }
  }
}
