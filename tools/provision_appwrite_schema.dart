// ignore_for_file: deprecated_member_use
// ignore_for_file: avoid_print
//dart run tools/provision_appwrite_schema.dart
import "dart:convert";
import "dart:io";
import "package:dart_appwrite/dart_appwrite.dart";
import "package:dart_appwrite/enums.dart" as enums;

const _defaultDbName = "WhatsUnity";
const _poll = Duration(milliseconds: 500);
const _timeout = Duration(minutes: 10);

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
  final spec = jsonDecode(specFile.readAsStringSync()) as Map<String, dynamic>;
  final collections = spec["collections"] as List<dynamic>;

  final client = Client()..setEndpoint(ep)..setProject(pid)..setKey(key);
  final d = Databases(client);

  await _ensureDb(d, dbId, dbName);
  for (final raw in collections) {
    final c = raw as Map<String, dynamic>;
    final cid = c["id"] as String;
    final cname = c["name"] as String;
    print("--- $cid ---");
    await _ensureCollection(d, dbId, cid, cname);
    for (final a in (c["attributes"] as List<dynamic>)) {
      await _ensureAttr(d, dbId, cid, a as List<dynamic>);
    }
    for (final a in (c["attributes"] as List<dynamic>)) {
      await _waitAttr(d, dbId, cid, (a as List)[1] as String);
    }
    for (final ix in (c["indexes"] as List<dynamic>)) {
      await _ensureIndex(d, dbId, cid, ix as Map<String, dynamic>);
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

Future<void> _ensureAttr(Databases d, String db, String col, List<dynamic> row) async {
  final t = row[0] as String;
  final k = row[1] as String;
  try {
    if (t == "s") {
        final size = (row[2] as num).toInt();
        final req = (row[3] as num) == 1;
        await d.createStringAttribute(
            databaseId: db, collectionId: col, key: k, size: size, xrequired: req);
    } else if (t == "x") {
        final req = (row[3] as num) == 1;
        await d.createTextAttribute(
            databaseId: db, collectionId: col, key: k, xrequired: req);
    } else if (t == "i") {
        final req = (row[3] as num) == 1;
        int? def;
        if (row.length > 4 && row[4] != null) def = (row[4] as num).toInt();
        await d.createIntegerAttribute(
            databaseId: db, collectionId: col, key: k, xrequired: req, xdefault: def);
    } else if (t == "b") {
        final req = (row[3] as num) == 1;
        bool? defb;
        if (row.length > 4 && row[4] is bool) defb = row[4] as bool?;
        await d.createBooleanAttribute(
            databaseId: db, collectionId: col, key: k, xrequired: req, xdefault: defb);
    } else if (t == "d") {
        final dreq = row.length > 3 ? (row[3] as num) == 1 : (row[2] as num) == 1;
        await d.createDatetimeAttribute(
            databaseId: db, collectionId: col, key: k, xrequired: dreq);
    } else if (t == "r") {
        final related = row[2] as String;
        final relType = _relT(row[3] as String);
        final onDel = _onDT(row[4] as String);
        await d.createRelationshipAttribute(
          databaseId: db,
          collectionId: col,
          relatedCollectionId: related,
          type: relType,
          key: k,
          onDelete: onDel,
        );
    }
  } on AppwriteException catch (e) {
    if (e.code != 409) rethrow;
  }
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

Future<void> _waitAttr(Databases d, String db, String col, String key) async {
  final end = DateTime.now().add(_timeout);
  while (DateTime.now().isBefore(end)) {
    stdout.write(".");
    final m = await d.getAttribute(databaseId: db, collectionId: col, key: key);
    final s = m.toMap()["status"]?.toString() ?? "";
    if (s == "failed" || s == "stuck") {
      stdout.writeln();
      throw StateError("attr $key: $s");
    }
    if (s == "available") {
      stdout.writeln();
      return;
    }
    await Future<void>.delayed(_poll);
  }
  stdout.writeln();
  throw StateError("timeout $key");
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

Future<void> _ensureIndex(Databases d, String db, String col, Map<String, dynamic> m) async {
  final t = _ixT(m["t"] as String);
  final attrs = (m["a"] as List<dynamic>).map((e) => e as String).toList();
  final ords = _ord(m["ord"] as String?, attrs.length);
  final lens = m["len"] == null
      ? null
      : (m["len"] as List<dynamic>).map((e) => (e as num).toInt()).toList();
  final key = m["key"] as String;
  try {
    await d.createIndex(
      databaseId: db,
      collectionId: col,
      key: key,
      type: t,
      attributes: attrs,
      orders: ords,
      lengths: lens,
    );
  } on AppwriteException catch (e) {
    if (e.code != 409) rethrow;
  }
}



