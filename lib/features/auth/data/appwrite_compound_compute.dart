import 'dart:convert';

import 'package:WhatsUnity/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../core/config/Enums.dart';
import '../../../core/config/app_directory_types.dart' show CompoundMembersResult, Users;
import '../../../core/models/CompoundsList.dart';
import '../../chat/data/models/chat_member_model.dart';

/// Background [Isolate] entry points for [compute] — synchronous only.

/// Resolves document/row id after [compute] and `Map` copies (key quirks across isolates / tables API).
String _resolveRowId(Map<String, dynamic> rowMap) {
  Object? rowIdValue =
      rowMap[r'$id'] ?? rowMap['\$id'] ?? rowMap[r'$Id'] ?? rowMap['id'];
  if (rowIdValue == null) {
    final nestedData = rowMap['data'];
    if (nestedData is Map) {
      final nestedDataMap = Map<String, dynamic>.from(nestedData);
      rowIdValue = nestedDataMap[r'id'] ??
          nestedDataMap['id'] ??
          nestedDataMap[r'$id'] ??
          nestedDataMap['\$id'];
    }
  }
  return rowIdValue?.toString() ?? '';
}

Map<String, dynamic> _extractRowData(Map<String, dynamic> rowMap) {
  final nestedData = rowMap['data'];
  if (nestedData is Map) {
    final nestedDataMap = Map<String, dynamic>.from(nestedData);
    if (nestedDataMap.isNotEmpty) return nestedDataMap;
  }
  // Flat row shape: custom columns on the root next to $metadata keys.
  final rowData = <String, dynamic>{};
  for (final entry in rowMap.entries) {
    final key = entry.key;
    if (key == 'data' || (key.isNotEmpty && key.startsWith(r'$'))) {
      continue;
    }
    rowData[key] = entry.value;
  }
  return rowData;
}

List<Map<String, dynamic>> _parseVerificationFiles(dynamic rawVerificationFiles) {
  if (rawVerificationFiles == null) return [];
  if (rawVerificationFiles is List) {
    return rawVerificationFiles
        .map((file) => Map<String, dynamic>.from(file as Map))
        .toList();
  }
  if (rawVerificationFiles is String && rawVerificationFiles.isNotEmpty) {
    try {
      final decodedVerificationFiles = jsonDecode(rawVerificationFiles);
      if (decodedVerificationFiles is List) {
        return decodedVerificationFiles
            .map((file) => Map<String, dynamic>.from(file as Map))
            .toList();
      }
    } catch (_) {}
  }
  return [];
}

/// Builds [Category] / [Compound] trees from serialized [Row.toMap] payloads.
List<Category> parseAppwriteCompoundsForIsolate(Map<String, dynamic> payload) {
  final categoryRows = (payload['categories'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  final compoundRows = (payload['compounds'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  final compoundsByCategoryId = <String, List<Compound>>{};
  final categoryIds = categoryRows
      .map(_resolveRowId)
      .where((categoryId) => categoryId.isNotEmpty)
      .toSet();

  for (final compoundRow in compoundRows) {
    final compoundData = _extractRowData(compoundRow);
    final categoryId = (compoundData['category_id'] ?? compoundRow['category_id'])
        ?.toString()
        .trim();
    final safeCategoryId = (categoryId != null &&
            categoryId.isNotEmpty &&
            categoryIds.contains(categoryId))
        ? categoryId
        : '';
    compoundsByCategoryId.putIfAbsent(safeCategoryId, () => []).add(
          Compound(
            id: _resolveRowId(compoundRow),
            name: compoundData['name'] as String? ?? '',
            developer: compoundData['developer'] as String?,
            city: compoundData['city'] as String?,
            pictureUrl: compoundData['picture_url'] as String?,
          ),
        );
  }

  final categories = <Category>[];
  for (final categoryRow in categoryRows) {
    final categoryId = _resolveRowId(categoryRow);
    categories.add(
      Category(
        id: categoryId,
        name: _extractRowData(categoryRow)['name'] as String? ?? '',
        compounds: compoundsByCategoryId[categoryId] ?? const [],
      ),
    );
  }
  final otherCategoryCompounds = compoundsByCategoryId[''];
  if (otherCategoryCompounds != null && otherCategoryCompounds.isNotEmpty) {
    categories.add(
      Category(
        id: 'uncategorized',
        name: 'Other',
        compounds: otherCategoryCompounds,
      ),
    );
  }
  if (kDebugMode) {
    final totalCompounds =
        categories.fold<int>(0, (sum, category) => sum + category.compounds.length);
    final uncategorizedCount = otherCategoryCompounds?.length ?? 0;
    AppLogger.d(
      "parseAppwriteCompounds: ${categoryRows.length} category row(s), "
      "${compoundRows.length} compound row(s) → ${categories.length} category bucket(s), "
      "$totalCompounds compound(s) listed ($uncategorizedCount in \"Other\" from unmatched category_id)",
      tag: 'Appwrite/isolate',
    );
  }
  return categories;
}

/// Builds [ChatMember] / [Users] lists from serialized [Row.toMap] payloads.
CompoundMembersResult parseAppwriteMembersForIsolate(Map<String, dynamic> payload) {
  final isAdmin = payload['isAdmin'] == true;
  final apartmentRows = (payload['apartments'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  final profileRows = (payload['profiles'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  final apartmentRowByUserId = <String, Map<String, dynamic>>{};
  for (final apartmentRow in apartmentRows) {
    final apartmentData = _extractRowData(apartmentRow);
    final userId = apartmentData['user_id']?.toString() ?? '';
    if (userId.isEmpty) continue;
    apartmentRowByUserId[userId] = apartmentData;
  }

  final members = <ChatMember>[];
  for (final profileRow in profileRows) {
    final profileId = _resolveRowId(profileRow);
    final profileData = _extractRowData(profileRow);
    final apartmentData = apartmentRowByUserId[profileId];
    members.add(
      ChatMember(
        id: profileId,
        displayName: profileData['display_name'] as String? ?? 'No Name',
        fullName: profileData['full_name'] as String?,
        avatarUrl: profileData['avatar_url'] as String?,
        building: apartmentData?['building_num']?.toString() ?? '',
        apartment: apartmentData?['apartment_num']?.toString() ?? '',
        phoneNumber: profileData['phone_number']?.toString() ?? '',
        ownerType: OwnerTypes.values.firstWhere(
          (type) => type.name == profileData['owner_type'],
          orElse: () => OwnerTypes.owner,
        ),
        userState: UserState.values.firstWhere(
          (state) => state.name == profileData['userState'],
          orElse: () => UserState.New,
        ),
      ),
    );
  }

  var memberData = <Users>[];
  if (isAdmin) {
    memberData = profileRows.map((profileRow) {
      final profileData = _extractRowData(profileRow);
      final updatedAtText = profileRow[r'$updatedAt']?.toString() ?? '';
      return Users(
        authorId: _resolveRowId(profileRow),
        phoneNumber: (profileData['phone_number'] ?? '').toString(),
        updatedAt: DateTime.tryParse(updatedAtText) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        ownerShipType: (profileData['owner_type'] ?? '').toString(),
        userState: (profileData['userState'] ?? '').toString(),
        actionTakenBy: (profileData['actionTakenBy'] ?? '').toString(),
        verFile: _parseVerificationFiles(profileData['verFiles']),
      );
    }).toList();
  }

  return CompoundMembersResult(members: members, membersData: memberData);
}
