import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../../core/config/Enums.dart';
import '../../../core/config/app_directory_types.dart' show CompoundMembersResult, Users;
import '../../../core/models/CompoundsList.dart';
import '../../chat/presentation/widgets/chatWidget/Details/ChatMember.dart';

/// Background [Isolate] entry points for [compute] — synchronous only.

/// Resolves document/row id after [compute] and `Map` copies (key quirks across isolates / tables API).
String _rowId(Map<String, dynamic> row) {
  Object? v = row[r'$id'] ?? row['\$id'] ?? row[r'$Id'] ?? row['id'];
  if (v == null) {
    final d = row['data'];
    if (d is Map) {
      final m = Map<String, dynamic>.from(d);
      v = m[r'id'] ?? m['id'] ?? m[r'$id'] ?? m['\$id'];
    }
  }
  return v?.toString() ?? '';
}

Map<String, dynamic> _rowData(Map<String, dynamic> row) {
  final d = row['data'];
  if (d is Map) {
    final m = Map<String, dynamic>.from(d);
    if (m.isNotEmpty) return m;
  }
  // Flat row shape: custom columns on the root next to $metadata keys.
  final out = <String, dynamic>{};
  for (final e in row.entries) {
    final k = e.key;
    if (k == 'data' || (k.isNotEmpty && k.startsWith(r'$'))) {
      continue;
    }
    out[k] = e.value;
  }
  return out;
}

/// Normalized category id for matching [compound_id] to [Category.id] (string-safe).
String _catKey(Object? v) {
  if (v == null) return '';
  final s = v.toString().trim();
  return s;
}

List<Map<String, dynamic>> _verFilesListFromProfile(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (v is String && v.isNotEmpty) {
    try {
      final d = jsonDecode(v);
      if (d is List) {
        return d
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
  }
  return [];
}

/// Builds [Category] / [Compound] trees from serialized [Row.toMap] payloads.
List<Category> parseAppwriteCompoundsForIsolate(Map<String, dynamic> payload) {
  final categoryRows = (payload['categories'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final compoundRows = (payload['compounds'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final byCategory = <String, List<Compound>>{};
  final catIds = categoryRows.map(_rowId).where((e) => e.isNotEmpty).toSet();

  for (final m in compoundRows) {
    final d = _rowData(m);
    final raw = _catKey(d['category_id'] ?? m['category_id']);
    final key = (raw.isNotEmpty && catIds.contains(raw)) ? raw : '';
    byCategory.putIfAbsent(key, () => []).add(
          Compound(
            id: _rowId(m),
            name: d['name'] as String? ?? '',
            developer: d['developer'] as String?,
            city: d['city'] as String?,
            pictureUrl: d['picture_url'] as String?,
          ),
        );
  }

  final out = <Category>[];
  for (final m in categoryRows) {
    final id = _rowId(m);
    out.add(
      Category(
        id: id,
        name: _rowData(m)['name'] as String? ?? '',
        compounds: byCategory[id] ?? const [],
      ),
    );
  }
  final uncategorized = byCategory[''];
  if (uncategorized != null && uncategorized.isNotEmpty) {
    out.add(
      Category(
        id: 'uncategorized',
        name: 'Other',
        compounds: uncategorized,
      ),
    );
  }
  if (kDebugMode) {
    final totalOut =
        out.fold<int>(0, (sum, c) => sum + c.compounds.length);
    final orphan = uncategorized?.length ?? 0;
    debugPrint(
      '[Appwrite/isolate] parseAppwriteCompounds: ${categoryRows.length} category row(s), '
      '${compoundRows.length} compound row(s) → ${out.length} category bucket(s), '
      '$totalOut compound(s) listed ($orphan in "Other" from unmatched category_id)',
    );
  }
  return out;
}

/// Builds [ChatMember] / [Users] lists from serialized [Row.toMap] payloads.
CompoundMembersResult parseAppwriteMembersForIsolate(Map<String, dynamic> payload) {
  final isAdmin = payload['isAdmin'] == true;
  final apartmentRows = (payload['apartments'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final profileRows = (payload['profiles'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final apartmentsMap = <String, Map<String, dynamic>>{};
  for (final m in apartmentRows) {
    final d = _rowData(m);
    final uid = d['user_id']?.toString() ?? '';
    if (uid.isEmpty) continue;
    apartmentsMap[uid] = d;
  }

  final membersList = <ChatMember>[];
  for (final m in profileRows) {
    final id = _rowId(m);
    final data = _rowData(m);
    final apt = apartmentsMap[id];
    membersList.add(
      ChatMember(
        id: id,
        displayName: data['display_name'] as String? ?? 'No Name',
        fullName: data['full_name'] as String?,
        avatarUrl: data['avatar_url'] as String?,
        building: apt?['building_num']?.toString() ?? '',
        apartment: apt?['apartment_num']?.toString() ?? '',
        phoneNumber: data['phone_number']?.toString() ?? '',
        ownerType: OwnerTypes.values.firstWhere(
          (type) => type.name == data['owner_type'],
          orElse: () => OwnerTypes.owner,
        ),
        userState: UserState.values.firstWhere(
          (state) => state.name == data['userState'],
          orElse: () => UserState.New,
        ),
      ),
    );
  }

  var memberData = <Users>[];
  if (isAdmin) {
    memberData = profileRows.map((m) {
      final data = _rowData(m);
      final updated = m[r'$updatedAt']?.toString() ?? '';
      return Users(
        authorId: _rowId(m),
        phoneNumber: (data['phone_number'] ?? '').toString(),
        updatedAt: DateTime.tryParse(updated) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        ownerShipType: (data['owner_type'] ?? '').toString(),
        userState: (data['userState'] ?? '').toString(),
        actionTakenBy: (data['actionTakenBy'] ?? '').toString(),
        verFile: _verFilesListFromProfile(data['verFiles']),
      );
    }).toList();
  }

  return CompoundMembersResult(members: membersList, membersData: memberData);
}
