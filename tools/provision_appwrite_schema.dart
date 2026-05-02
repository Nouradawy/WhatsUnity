// ignore_for_file: deprecated_member_use
// ignore_for_file: avoid_print
// dart run tools/provision_appwrite_schema.dart
import "dart:convert";
import "dart:io";
import "package:dart_appwrite/dart_appwrite.dart";
import "package:dart_appwrite/enums.dart" as enums;

const _defaultDbName = "WhatsUnity";
const _poll = Duration(milliseconds: 500);
const _timeout = Duration(minutes: 2);

Map<String, String> _env = {};

void _loadEnv() {
  _env = Map<String, String>.from(Platform.environment);
  final f = File.fromUri(Platform.script.resolve("../.env"));
  if (!f.existsSync()) return;
  for (var line in f.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith("#") || !line.contains("=")) continue;
    final i = line.indexOf("=");
    var k = line.substring(0, i).trim();
    var v = line.substring(i + 1).trim();
    if (v.length >= 2 && v[0] == v[v.length - 1] && (v[0] == "\"" || v[0] == "'")) {
      v = v.substring(1, v.length - 1);
    }
    _env[k] = v;
  }
}

String? _g(String k) => _env[k] ?? _env[k.toUpperCase()];

final _perms = [
  Permission.read(Role.users()),
  Permission.create(Role.users()),
  Permission.update(Role.users()),
  Permission.delete(Role.users()),
];

// ─────────────────────────────────────────────────────────────────────────────
// Schema Models (Fixed "fromJson factories for schema specs")
// ─────────────────────────────────────────────────────────────────────────────

class AttributeSpec {
  final String type; // s, x, i, b, d, r
  final String key;
  final int? size;
  final bool required;
  final dynamic defaultValue;
  final String? relatedCollection;
  final String? relationshipType;
  final String? onDelete;

  AttributeSpec({
    required this.type,
    required this.key,
    this.size,
    required this.required,
    this.defaultValue,
    this.relatedCollection,
    this.relationshipType,
    this.onDelete,
  });

  factory AttributeSpec.fromList(List<dynamic> row) {
    final t = row[0] as String;
    final k = row[1] as String;

    switch (t) {
      case "s": // String
        return AttributeSpec(
          type: t,
          key: k,
          size: (row[2] as num).toInt(),
          required: (row[3] as num) == 1,
          defaultValue: row.length > 4 ? row[4] : null,
        );
      case "x": // Text
        return AttributeSpec(
          type: t,
          key: k,
          required: (row[3] as num) == 1,
        );
      case "i": // Integer
        return AttributeSpec(
          type: t,
          key: k,
          required: (row[3] as num) == 1,
          defaultValue: (row.length > 4 && row[4] != null) ? (row[4] as num).toInt() : null,
        );
      case "b": // Boolean
        return AttributeSpec(
          type: t,
          key: k,
          required: (row[3] as num) == 1,
          defaultValue: (row.length > 4 && row[4] is bool) ? row[4] as bool : null,
        );
      case "d": // DateTime
        return AttributeSpec(
          type: t,
          key: k,
          required: row.length > 3 ? (row[3] as num) == 1 : (row[2] as num) == 1,
        );
      case "r": // Relationship
        return AttributeSpec(
          type: t,
          key: k,
          relatedCollection: row[2] as String,
          relationshipType: row[3] as String,
          onDelete: row[4] as String,
          required: row.length > 5 ? (row[5] as num) == 1 : false,
        );
      default:
        throw Exception("Unknown attribute type: $t");
    }
  }
}

class IndexSpec {
  final String key;
  final String type; // k, u, ft
  final List<String> attributes;
  final String? orders;
  final List<int>? lengths;

  IndexSpec({
    required this.key,
    required this.type,
    required this.attributes,
    this.orders,
    this.lengths,
  });

  factory IndexSpec.fromMap(Map<String, dynamic> m) {
    return IndexSpec(
      key: m["key"] as String,
      type: m["t"] as String,
      attributes: (m["a"] as List<dynamic>).map((e) => e as String).toList(),
      orders: m["ord"] as String?,
      lengths: m["len"] == null
          ? null
          : (m["len"] as List<dynamic>).map((e) => (e as num).toInt()).toList(),
    );
  }
}

class CollectionSpec {
  final String id;
  final String name;
  final List<AttributeSpec> attributes;
  final List<IndexSpec> indexes;

  CollectionSpec({
    required this.id,
    required this.name,
    required this.attributes,
    required this.indexes,
  });

  factory CollectionSpec.fromMap(Map<String, dynamic> m) {
    return CollectionSpec(
      id: m["id"] as String,
      name: m["name"] as String,
      attributes: (m["attributes"] as List<dynamic>)
          .map((a) => AttributeSpec.fromList(a as List<dynamic>))
          .toList(),
      indexes: (m["indexes"] as List<dynamic>)
          .map((ix) => IndexSpec.fromMap(ix as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Execution Logic
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  _loadEnv();
  final ep = _g("APPWRITE_ENDPOINT");
  final pid = _g("APPWRITE_PROJECT_ID");
  final key = _g("APPWRITE_API_KEY");
  final dbId = _g("APPWRITE_DATABASE_ID");
  final dbName = _g("APPWRITE_DB_NAME") ?? _defaultDbName;

  if (ep == null || pid == null || key == null || dbId == null) {
    print("Missing APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY, or APPWRITE_DATABASE_ID");
    exit(1);
  }

  final specFile = File.fromUri(Platform.script.resolve("provision_spec.json"));
  if (!specFile.existsSync()) {
    print("Missing ${specFile.path}");
    exit(1);
  }

  final specData = jsonDecode(specFile.readAsStringSync()) as Map<String, dynamic>;
  final collectionSpecs = (specData["collections"] as List<dynamic>)
      .map((c) => CollectionSpec.fromMap(c as Map<String, dynamic>))
      .toList();

  final client = Client()..setEndpoint(ep)..setProject(pid)..setKey(key);
  final d = Databases(client);

  await _ensureDb(d, dbId, dbName);

  for (final spec in collectionSpecs) {
    print("--- ${spec.id} ---");
    await _ensureCollection(d, dbId, spec.id, spec.name);

    final createdAttributeKeys = <String>[];
    for (final attr in spec.attributes) {
      final createdNow = await _ensureAttribute(d, dbId, spec.id, attr);
      if (createdNow) createdAttributeKeys.add(attr.key);
    }

    // Wait only for attributes created in this run.
    for (final key in createdAttributeKeys) {
      await _waitAttribute(d, dbId, spec.id, key);
    }

    for (final index in spec.indexes) {
      await _ensureIndex(d, dbId, spec.id, index);
    }
  }

  print("Done.");
}

Future<void> _ensureDb(Databases d, String id, String name) async {
  try {
    await d.get(databaseId: id);
    print("database ok: $id");
  } on AppwriteException catch (e) {
    if (e.code == 404) {
      print("create database $id");
      await d.create(databaseId: id, name: name);
    } else {
      rethrow;
    }
  }
}

Future<void> _ensureCollection(Databases d, String db, String col, String name) async {
  try {
    await d.createCollection(
      databaseId: db,
      collectionId: col,
      name: name,
      permissions: _perms,
      documentSecurity: true,
    );
  } on AppwriteException catch (e) {
    if (e.code != 409) rethrow;
    print("collection exists: $col");
  }
}

Future<bool> _ensureAttribute(Databases d, String dbId, String colId, AttributeSpec spec) async {
  final existing = await _tryGetAttribute(d, dbId, colId, spec.key);
  if (existing != null) {
    final existingType = _existingAttributeType(existing);
    final desiredType = _desiredAttributeType(spec.type);
    if (existingType != null && existingType != desiredType) {
      stderr.writeln(
        'schema warning: $colId.${spec.key} already exists as "$existingType" '
        'but spec expects "$desiredType". Keeping existing attribute to avoid provisioning failure.',
      );
    }
    return false;
  }

  try {
    switch (spec.type) {
      case "s":
        await d.createStringAttribute(
          databaseId: dbId,
          collectionId: colId,
          key: spec.key,
          size: spec.size!,
          xrequired: spec.required,
          xdefault: spec.defaultValue?.toString(),
        );
      case "x":
        await d.createTextAttribute(
          databaseId: dbId,
          collectionId: colId,
          key: spec.key,
          xrequired: spec.required,
          xdefault: spec.defaultValue?.toString(),
        );
      case "i":
        await d.createIntegerAttribute(
          databaseId: dbId,
          collectionId: colId,
          key: spec.key,
          xrequired: spec.required,
          xdefault: spec.defaultValue as int?,
        );
      case "b":
        await d.createBooleanAttribute(
          databaseId: dbId,
          collectionId: colId,
          key: spec.key,
          xrequired: spec.required,
          xdefault: spec.defaultValue as bool?,
        );
      case "d":
        await d.createDatetimeAttribute(
          databaseId: dbId,
          collectionId: colId,
          key: spec.key,
          xrequired: spec.required,
        );
      case "r":
        await d.createRelationshipAttribute(
          databaseId: dbId,
          collectionId: colId,
          relatedCollectionId: spec.relatedCollection!,
          type: _relT(spec.relationshipType!),
          key: spec.key,
          onDelete: _onDT(spec.onDelete!),
        );
    }
    return true;
  } on AppwriteException catch (e) {
    final msg = (e.message ?? '').toLowerCase();
    final alreadyExists = e.code == 409 || msg.contains('already exists');
    if (!alreadyExists) rethrow;
    return false;
  }
}

Future<dynamic> _tryGetAttribute(
  Databases d,
  String dbId,
  String colId,
  String key,
) async {
  try {
    return await d.getAttribute(databaseId: dbId, collectionId: colId, key: key);
  } on AppwriteException catch (e) {
    if (e.code == 404) return null;
    rethrow;
  } catch (e) {
    stderr.writeln(
      'schema warning: getAttribute failed for $colId.$key ($e). '
      'Falling back to create-and-ignore-409 path.',
    );
    return null;
  }
}

String? _existingAttributeType(dynamic attr) {
  try {
    final t = attr.type?.toString();
    if (t == null || t.isEmpty) return null;
    return t.toLowerCase();
  } catch (_) {
    return null;
  }
}

String _desiredAttributeType(String shortType) {
  return switch (shortType) {
    's' => 'string',
    'x' => 'string',
    'i' => 'integer',
    'b' => 'boolean',
    'd' => 'datetime',
    'r' => 'relationship',
    _ => shortType,
  };
}

enums.RelationshipType _relT(String t) {
  return switch (t) {
    "oneToOne" => enums.RelationshipType.oneToOne,
    "manyToOne" => enums.RelationshipType.manyToOne,
    "oneToMany" => enums.RelationshipType.oneToMany,
    "manyToMany" => enums.RelationshipType.manyToMany,
    _ => enums.RelationshipType.oneToOne,
  };
}

enums.RelationMutate _onDT(String t) {
  return switch (t.toLowerCase()) {
    "cascade" => enums.RelationMutate.cascade,
    "restrict" => enums.RelationMutate.restrict,
    "setnull" => enums.RelationMutate.setNull,
    _ => enums.RelationMutate.cascade,
  };
}

Future<void> _waitAttribute(Databases d, String db, String col, String key) async {
  final end = DateTime.now().add(_timeout);
  while (DateTime.now().isBefore(end)) {
    stdout.write(".");
    dynamic m;
    try {
      m = await d.getAttribute(databaseId: db, collectionId: col, key: key);
    } catch (e) {
      stdout.writeln();
      stderr.writeln(
        'schema warning: unable to poll attribute status for $col.$key ($e). Continuing.',
      );
      return;
    }
    final s = m.status; // Accessing status directly via models.Attribute
    if (s == "failed" || s == "stuck") {
      stdout.writeln();
      stderr.writeln('schema warning: attr $col.$key is $s. Continuing.');
      return;
    }
    if (s == "available") {
      stdout.writeln();
      return;
    }
    await Future<void>.delayed(_poll);
  }
  stdout.writeln();
  stderr.writeln('schema warning: timeout waiting for $col.$key. Continuing.');
}

enums.DatabasesIndexType _ixT(String t) {
  return switch (t) {
    "k" => enums.DatabasesIndexType.key,
    "u" => enums.DatabasesIndexType.unique,
    "ft" => enums.DatabasesIndexType.fulltext,
    _ => enums.DatabasesIndexType.key,
  };
}

List<enums.OrderBy>? _ord(String? s, int n) {
  if (s == null || s.length != n) return null;
  return List<enums.OrderBy>.generate(
      n, (i) => s[i] == "d" ? enums.OrderBy.desc : enums.OrderBy.asc);
}

Future<void> _ensureIndex(Databases d, String dbId, String colId, IndexSpec spec) async {
  try {
    await d.createIndex(
      databaseId: dbId,
      collectionId: colId,
      key: spec.key,
      type: _ixT(spec.type),
      attributes: spec.attributes,
      orders: _ord(spec.orders, spec.attributes.length),
      lengths: spec.lengths,
    );
  } on AppwriteException catch (e) {
    if (e.code == 409) return;
    final msg = (e.message ?? '').toLowerCase();
    final isInvalidIndex = msg.contains('index_invalid') ||
        (msg.contains('maximum') && msg.contains('767'));
    if (isInvalidIndex) {
      stderr.writeln(
        'schema warning: skipped index $colId.${spec.key} ($msg).',
      );
      return;
    }
    rethrow;
  }
}
