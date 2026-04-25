import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint, kDebugMode;
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/app_directory_types.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/appwrite.dart'
    show appwriteDatabaseId, appwriteDatabases;
import '../../../../core/models/CompoundsList.dart';
import '../../../../core/network/CacheHelper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../appwrite_compound_compute.dart';

// APPWRITE_SCHEMA.md — collection ids (provision_spec.json)
const String _kColUserApartments = 'user_apartments';
const String _kColCompoundCategories = 'compound_categories';
const String _kColCompounds = 'compounds';
const String _kColProfiles = 'profiles';
const String _kColBuildings = 'buildings';
const String _kColChannels = 'channels';
const String _kColUserRoles = 'user_roles';
const int _kListLimit = 2000;

/// Auth uses Appwrite [Account]; profile and registration side-effects use
/// [Databases] / [TablesDB] against APPWRITE_SCHEMA collections (string ids).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required Account appwriteAccount,
    required TablesDB appwriteTables,
  })  : _appwriteAccount = appwriteAccount,
        _tables = appwriteTables {
    _checkExistingSession();
  }

  final AuthRemoteDataSource remoteDataSource;

  final Account _appwriteAccount;
  final TablesDB _tables;

  /// Returns the authoritative authenticated user id from Appwrite [Account],
  /// falling back to the cached [_currentUser] when the account endpoint is unavailable.
  Future<String?> _resolveAuthenticatedUserId() async {
    try {
      final user = await _appwriteAccount.get();
      final id = user.$id.trim();
      if (id.isNotEmpty) return id;
    } catch (_) {
      // Fallback below.
    }
    final cached = _currentUser?.id.trim();
    if (cached == null || cached.isEmpty) return null;
    return cached;
  }

  // ── Auth state stream ─────────────────────────────────────────────────────
  final _authController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  void _notify(AppUser? user) {
    _currentUser = user;
    if (user != null) {
      unawaited(CacheHelper.saveLastActiveUserId(user.id));
    }
    _authController.add(user);
  }

  @override
  Stream<AppUser?> get onAuthStateChange => _authController.stream;

  @override
  AppUser? get currentUser => _currentUser;

  /// Async session probe fired from the constructor so [AuthManager] and
  /// the cubit receive an event without needing to await construction.
  Future<void> _checkExistingSession() async {
    final user = await remoteDataSource.getCurrentUser();
    _notify(user);
  }

  @override
  Future<AppUser?> fetchCurrentUser() async {
    final user = await remoteDataSource.getCurrentUser();
    _currentUser = user;
    if (user != null) {
      unawaited(CacheHelper.saveLastActiveUserId(user.id));
    }
    return user;
  }

  @override
  void primeCurrentUser(AppUser user) {
    _currentUser = user;
    unawaited(CacheHelper.saveLastActiveUserId(user.id));
  }

  // ── Auth operations ────────────────────────────────────────────────────────

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final user = await remoteDataSource.signInWithPassword(
      email: email,
      password: password,
    );
    _notify(user);
    return user;
  }

  /// Google auth goes through Appwrite's native OAuth2 flow.
  @override
  Future<AppUser?> signInWithGoogle() async {
    final user = await remoteDataSource.signInWithGoogle();
    _notify(user);
    return user;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    await remoteDataSource.signUp(email: email, password: password, data: data);
    // Triggers `users.*.update.prefs` → on_user_register (Appwrite function).
    await _updateProvisioningPrefs(_provisioningMapFromSignUpData(data));
    // Fetch and cache the newly created user (includes prefs in userMetadata).
    final user = await remoteDataSource.getCurrentUser();
    _notify(user);
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
    await CacheHelper.removeData(CacheHelper.compoundCurrentIndexKey);
    await CacheHelper.removeData(CacheHelper.lastActiveUserIdKey);
    await CacheHelper.removeData("MyCompounds");
    _notify(null);
  }

  // ── Profile / account management ─────────────────────────────────────────

  @override
  Future<void> updateProfile({
    required String fullName,
    required String displayName,
    required OwnerTypes ownerType,
    required String phoneNumber,
  }) async {
    final userId = await _resolveAuthenticatedUserId();
    if (userId == null) return;

    // Update the display name on the Appwrite account.
    await _appwriteAccount.updateName(name: displayName);

    final payload = <String, dynamic>{
      'full_name': fullName,
      'display_name': displayName,
      'owner_type': ownerType.name,
      'phone_number': phoneNumber,
    };
    try {
      await appwriteDatabases.updateDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kColProfiles,
        documentId: userId,
        data: payload,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Google OAuth first-login can race profile provisioning; create it with `$id=userId`.
        await appwriteDatabases.createDocument(
          databaseId: appwriteDatabaseId,
          collectionId: _kColProfiles,
          documentId: userId,
          data: <String, dynamic>{
            ...payload,
            'version': 0,
          },
        );
      } else {
        rethrow;
      }
    }
  }

  /// Prefs keys consumed by [functions/on_user_register] (users.*.update.prefs).
  Map<String, dynamic> _provisioningMapFromSignUpData(
    Map<String, dynamic> data,
  ) {
    String? strVal(List<String> keys) {
      for (final k in keys) {
        if (!data.containsKey(k)) continue;
        final v = data[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        return s;
      }
      return null;
    }

    final m = <String, dynamic>{};
    final fullName = strVal(const ['full_name', 'fullName']);
    final displayName = strVal(const ['display_name', 'displayName']);
    if (fullName != null) m['full_name'] = fullName;
    if (displayName != null) m['display_name'] = displayName;
    final ownerType = strVal(const ['ownerType', 'owner_type']);
    if (ownerType != null) m['ownerType'] = ownerType;
    final phone = strVal(const ['phoneNumber', 'phone_number']);
    if (phone != null) m['phoneNumber'] = phone;
    final avatar = strVal(const ['avatar_url', 'avatarUrl']);
    if (avatar != null) m['avatar_url'] = avatar;

    final roleRaw = data['role_id'] ?? data['roleId'];
    if (roleRaw != null) {
      final r = roleRaw is int ? roleRaw : int.tryParse(roleRaw.toString());
      if (r != null) m['role_id'] = r;
    }

    final compound = data['compound_id'] ?? data['compoundId'];
    if (compound != null && '$compound'.trim().isNotEmpty) {
      m['compound_id'] = compound.toString();
    }
    final building = data['building_num'] ?? data['buildingNum'];
    if (building != null && '$building'.trim().isNotEmpty) {
      m['building_num'] = building.toString();
    }
    final apt = data['apartment_num'] ?? data['apartmentNum'];
    if (apt != null && '$apt'.trim().isNotEmpty) {
      m['apartment_num'] = apt.toString();
    }
    return m;
  }

  Map<String, dynamic> _provisioningMapFromCompleteRegistration({
    required String fullName,
    required String userName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    required int roleId,
    required String buildingName,
    required String apartmentNum,
    required String compoundId,
  }) {
    return {
      'full_name': fullName,
      'display_name': userName,
      'ownerType': ownerType.name,
      'phoneNumber': phoneNumber,
      'role_id': roleId,
      'compound_id': compoundId,
      'building_num': buildingName,
      'apartment_num': apartmentNum,
    };
  }

  /// Merges with existing [Account] prefs and writes, so Google OAuth users keep
  /// any prior keys while completing registration.
  Future<void> _updateProvisioningPrefs(Map<String, dynamic> next) async {
    if (next.isEmpty) return;
    final merged = await _appwriteAccount.getPrefs();
    final out = Map<String, dynamic>.from(merged.data);
    for (final e in next.entries) {
      if (e.value != null) out[e.key] = e.value;
    }
    await _appwriteAccount.updatePrefs(prefs: out);
  }

  @override
  Future<void> completeRegistration({
    required String fullName,
    required String userName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    required int roleId,
    required String buildingName,
    required String apartmentNum,
    required String compoundId,
  }) async {
    final userId = await _resolveAuthenticatedUserId();
    if (userId == null) return;

    // 0. Appwrite: same prefs event as email sign-up (Google registers here).
    try {
      await _updateProvisioningPrefs(
        _provisioningMapFromCompleteRegistration(
          fullName: fullName,
          userName: userName,
          ownerType: ownerType,
          phoneNumber: phoneNumber,
          roleId: roleId,
          buildingName: buildingName,
          apartmentNum: apartmentNum,
          compoundId: compoundId,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('completeRegistration: updatePrefs $e');
      }
      rethrow;
    }

    final profilePayload = <String, dynamic>{
      'full_name': fullName,
      'display_name': userName,
      'owner_type': ownerType.name,
      'phone_number': phoneNumber,
    };
    try {
      await appwriteDatabases.updateDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kColProfiles,
        documentId: userId,
        data: profilePayload,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Ensure profile exists for Google/OAuth path where provisioning function is delayed.
        await appwriteDatabases.createDocument(
          databaseId: appwriteDatabaseId,
          collectionId: _kColProfiles,
          documentId: userId,
          data: <String, dynamic>{
            ...profilePayload,
            'version': 0,
          },
        );
      } else {
        rethrow;
      }
    }

    if (roleId != 1) {
      try {
        await appwriteDatabases.updateDocument(
          databaseId: appwriteDatabaseId,
          collectionId: _kColUserRoles,
          documentId: userId,
          data: {'user_id': userId, 'role_id': roleId},
        );
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await appwriteDatabases.createDocument(
            databaseId: appwriteDatabaseId,
            collectionId: _kColUserRoles,
            documentId: userId,
            data: {'user_id': userId, 'role_id': roleId, 'version': 0},
          );
        } else {
          rethrow;
        }
      }
    }

    final buildings = await appwriteDatabases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kColBuildings,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('building_name', buildingName),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );

    late final String buildingDocId;
    if (buildings.documents.isEmpty) {
      final created = await appwriteDatabases.createDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kColBuildings,
        documentId: ID.unique(),
        data: {
          'compound_id': compoundId,
          'building_name': buildingName,
          'version': 0,
        },
      );
      buildingDocId = created.$id;
    } else {
      buildingDocId = buildings.documents.first.$id;
    }

    final channels = await appwriteDatabases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kColChannels,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('building_id', buildingDocId),
        Query.equal('type', 'BUILDING_CHAT'),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );
    if (channels.documents.isEmpty) {
      await appwriteDatabases.createDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kColChannels,
        documentId: ID.unique(),
        data: {
          'compound_id': compoundId,
          'building_id': buildingDocId,
          'name': 'Building $buildingName Chat',
          'type': 'BUILDING_CHAT',
          'version': 0,
        },
      );
    }

    final existingMine = await appwriteDatabases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kColUserApartments,
      queries: [
        Query.equal('user_id', userId),
        Query.equal('compound_id', compoundId),
        Query.equal('building_num', buildingName),
        Query.equal('apartment_num', apartmentNum),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );
    if (existingMine.documents.isEmpty) {
      await appwriteDatabases.createDocument(
        databaseId: appwriteDatabaseId,
        collectionId: _kColUserApartments,
        documentId: ID.unique(),
        data: {
          'user_id': userId,
          'compound_id': compoundId,
          'building_num': buildingName,
          'apartment_num': apartmentNum,
          'version': 0,
        },
      );
    }
  }

  @override
  Future<void> uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required void Function(int index, double progress) onProgress,
  }) async {
    await remoteDataSource.uploadVerificationFiles(
      files: files,
      userId: userId,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> isApartmentTaken({
    required String compoundId,
    required String buildingName,
    required String apartmentNum,
  }) async {
    final res = await appwriteDatabases.listDocuments(
      databaseId: appwriteDatabaseId,
      collectionId: _kColUserApartments,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('building_num', buildingName),
        Query.equal('apartment_num', apartmentNum),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );
    return res.documents.isNotEmpty;
  }

  @override
  Future<String?> getDefaultCompoundId(String userId) async {
    try {
      final res = await _tables.listRows(
        databaseId: appwriteDatabaseId,
        tableId: _kColUserApartments,
        queries: [
          Query.equal('user_id', userId),
          Query.isNull('deleted_at'),
          Query.orderDesc(r'$createdAt'),
          Query.limit(1),
        ],
      );
      if (res.rows.isEmpty) return null;
      final v = res.rows.first.data['compound_id'];
      if (v == null) return null;
      return v.toString();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getDefaultCompoundId (Appwrite): $e');
      }
      return null;
    }
  }

  @override
  Future<void> selectCompound({
    required String compoundId,
    required String compoundName,
    required bool atWelcome,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[Appwrite] selectCompound: saving compoundId=$compoundId name="$compoundName" '
        'atWelcome=$atWelcome (CacheHelper + MyCompounds JSON)',
      );
    }
    await CacheHelper.saveCompoundCurrentIndex(compoundId);
    if (atWelcome) {
      final myCompounds = {
        '0': "Add New Community",
        compoundId.toString(): compoundName,
      };
      await CacheHelper.saveData(
        key: "MyCompounds",
        value: json.encode(myCompounds),
      );
    }
  }

  /// TODO(Phase-5 UI): Appwrite's email-change flow requires the current
  /// password.  Once OtpScreen is migrated this should call
  /// `_appwriteAccount.updateEmail(email: newEmail, password: currentPassword)`.
  @override
  Future<void> requestEmailChange(String newEmail, {String? redirectUrl}) {
    throw UnimplementedError(
      'requestEmailChange is not yet implemented for Appwrite. '
      'See MIGRATION_PLAN.md Phase-5 (OtpScreen migration).',
    );
  }

  /// TODO(Phase-5 UI): Appwrite requires the old password.
  /// Once ProfilePage is updated to collect it, thread it through here.
  @override
  Future<void> updatePassword(String newPassword) {
    throw UnimplementedError(
      'updatePassword requires the current password in Appwrite. '
      'See MIGRATION_PLAN.md Phase-5 (ProfilePage migration).',
    );
  }

  // ── Data-loading helpers ──────────────────────────────────────────────────

  @override
  Future<List<Category>> loadCompounds() async {
    return _loadCompoundsFromAppwrite();
  }

  Future<List<Category>> _loadCompoundsFromAppwrite() async {
    final catDocs = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColCompoundCategories,
      queries: [
        Query.isNull('deleted_at'),
        Query.orderAsc('name'),
        Query.limit(500),
      ],
    );
    final compoundDocs = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColCompounds,
      queries: [Query.isNull('deleted_at'), Query.limit(5000)],
    );

    if (kDebugMode) {
      debugPrint(
        '[Appwrite] loadCompounds listRows: databaseId=$appwriteDatabaseId '
        'categoriesTable=$_kColCompoundCategories compoundsTable=$_kColCompounds '
        '→ ${catDocs.rows.length} category row(s), ${compoundDocs.rows.length} compound row(s)',
      );
    }

    // Client listRows is permission-scoped. Console "sees" all rows; the mobile
    // client only sees rows where the table allows Read for the current session
    // (e.g. role "users") or for guests ("any") during signup.
    if (kDebugMode &&
        (catDocs.rows.isEmpty || compoundDocs.rows.isEmpty)) {
      try {
        final u = await _appwriteAccount.get();
        debugPrint(
          '[Appwrite] loadCompounds: listRows is empty but a session exists '
          '(userId=${u.$id}). If the console shows rows, add Read permissions on '
          'tables $_kColCompoundCategories & $_kColCompounds for Users (or Any '
          'if this screen runs before sign-in).',
        );
      } on AppwriteException catch (e) {
        if (e.code == 401) {
          debugPrint(
            '[Appwrite] loadCompounds: no Appwrite session (401). listRows for '
            'compounds is empty. Either sign in first, or add table Read=**Any** '
            'for the community list during signup, then tighten later.',
          );
        } else {
          debugPrint(
            '[Appwrite] loadCompounds: could not read session: ${e.message}',
          );
        }
      } catch (e) {
        debugPrint('[Appwrite] loadCompounds: session check failed: $e');
      }
    }

    final parsed =
        await compute(parseAppwriteCompoundsForIsolate, <String, dynamic>{
          'categories': catDocs.rows.map((r) => r.toMap()).toList(),
          'compounds': compoundDocs.rows.map((r) => r.toMap()).toList(),
        });

    if (kDebugMode) {
      final total = parsed.fold<int>(0, (sum, c) => sum + c.compounds.length);
      debugPrint(
        '[Appwrite] loadCompounds after compute: ${parsed.length} category bucket(s), '
        '$total compound(s) in tree (UI categories may include "Other" for unmatched)',
      );
    }

    return parsed;
  }

  @override
  Future<CompoundMembersResult> loadCompoundMembers(
    String compoundId, {
    Roles? role,
  }) async {
    return _loadCompoundMembersFromAppwrite(compoundId, role: role);
  }

  Future<CompoundMembersResult> _loadCompoundMembersFromAppwrite(
    String compoundId, {
    Roles? role,
  }) async {
    final isAdmin = role == Roles.admin;
    final ua = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColUserApartments,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.isNull('deleted_at'),
        Query.orderDesc(r'$createdAt'),
        Query.limit(_kListLimit),
      ],
    );
    if (ua.rows.isEmpty) {
      return CompoundMembersResult(members: [], membersData: []);
    }

    final userIds = <String>[];
    for (final row in ua.rows) {
      final uid = row.data['user_id']?.toString() ?? '';
      if (uid.isNotEmpty) userIds.add(uid);
    }
    if (userIds.isEmpty) {
      return CompoundMembersResult(members: [], membersData: []);
    }

    final prof = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColProfiles,
      queries: [
        Query.equal(r'$id', userIds),
        Query.isNull('deleted_at'),
        Query.limit(_kListLimit),
      ],
    );

    return compute(parseAppwriteMembersForIsolate, <String, dynamic>{
      'isAdmin': isAdmin,
      'apartments': ua.rows.map((r) => r.toMap()).toList(),
      'profiles': prof.rows.map((r) => r.toMap()).toList(),
    });
  }
}
