/**
 * [AuthRepositoryImpl]
 *
 * This file orchestrates all authentication and user management logic.
 */
import 'dart:async';
import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:WhatsUnity/core/utils/app_logger.dart';
import '../../../../core/config/app_directory_types.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/appwrite.dart' show appwriteDatabaseId;
import '../../../../core/models/CompoundsList.dart';
import '../../../../core/network/CacheHelper.dart';
import '../../../../core/constants/Constants.dart';
import '../../domain/entities/app_user.dart';
import '../datasources/auth_local_data_source.dart';
import '../../domain/entities/auth_session_preparation_result.dart';
import '../../domain/entities/registration_result.dart';
import '../../../../features/chat/data/models/chat_member_model.dart';
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

/// Auth uses Appwrite [Account]; profile and registration side-effects use
/// [Databases] / [TablesDB] against APPWRITE_SCHEMA collections (string ids).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required Account appwriteAccount,
    required TablesDB appwriteTables,
  }) : _appwriteAccount = appwriteAccount,
       _tables = appwriteTables {
    _remoteCheckExistingSession();
  }

  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  final Account _appwriteAccount;
  final TablesDB _tables;

  List<Category>? _cachedCategories;
  List<String>? _cachedLogos;

  /// Returns the authoritative authenticated user id from Appwrite [Account],
  /// falling back to the cached [_currentUser] when the account endpoint is unavailable.
  Future<String?> _fetchAuthenticatedUserId() async {
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
    AppLogger.d("_notify: user=${user?.id}");
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
  ///
  /// Errors must not escape as unhandled async errors (common on web when
  /// Appwrite returns non-401 failures, CORS blocks, or the endpoint/project is wrong).
  Future<void> _remoteCheckExistingSession() async {
    try {
      final user = await remoteDataSource.remoteFetchCurrentUser();
      _notify(user);
    } catch (e, st) {
      AppLogger.e("_remoteCheckExistingSession failed", error: e, stackTrace: st);
      _notify(null);
    }
  }

  @override
  Future<AppUser?> fetchCurrentUser() async {
    final user = await remoteDataSource.remoteFetchCurrentUser();
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

  @override
  Future<AuthSessionPreparationResult> prepareAuthSession() async {
    AppLogger.d("prepareAuthSession starting...");
    
    // Use cached data if available to avoid redundant network calls
    List<Category> currentCategories = _cachedCategories ?? [];
    List<String> currentLogos = _cachedLogos ?? [];

    try {
      if (currentCategories.isEmpty) {
        AppLogger.d("Loading compounds (cache empty)...");
        currentCategories = await loadCompounds();
      } else {
        AppLogger.d("Using cached compounds (${currentCategories.length} categories)");
      }
    } catch (e, st) {
      AppLogger.e("prepareAuthSession: loadCompounds failed", error: e, stackTrace: st);
    }

    try {
      if (currentLogos.isEmpty) {
        AppLogger.d("Loading compound logos (cache empty)...");
        currentLogos = await AssetHelper.loadCompoundLogos();
        _cachedLogos = currentLogos;
      } else {
        AppLogger.d("Using cached compound logos (${currentLogos.length} logos)");
      }
    } catch (e, st) {
      AppLogger.e("prepareAuthSession: loadCompoundLogos failed", error: e, stackTrace: st);
    }

    AppUser? currentUserAuth;
    try {
      AppLogger.d("Fetching current remote user...");
      currentUserAuth = await fetchCurrentUser();
      AppLogger.d("Current remote user: ${currentUserAuth?.id}");
    } catch (e, st) {
      AppLogger.e("prepareAuthSession: fetchCurrentUser failed", error: e, stackTrace: st);
      currentUserAuth = null;
    }

    AppLogger.d("Checking local session...");
    final lastUserId = await CacheHelper.getLastActiveUserId();
    Map<String, dynamic>? localSession;

    if (lastUserId != null && lastUserId.isNotEmpty) {
      AppLogger.d("Fetching local session for $lastUserId");
      localSession = await localDataSource.localFetchSession(lastUserId);
      AppLogger.d("Local session found: ${localSession != null}");
    }

    if (currentUserAuth == null && localSession != null) {
      try {
        AppLogger.d("Restoring user from local session");
        final email = localSession['email']?.toString();
        final rid = localSession['role_id'];
        final Map<String, dynamic>? meta = rid != null ? <String, dynamic>{'role_id': rid} : null;
        currentUserAuth = AppUser(
          id: lastUserId!,
          email: email,
          userMetadata: meta,
        );
        primeCurrentUser(currentUserAuth);
      } catch (e, st) {
        AppLogger.e("prepareAuthSession: offline user restore from SQLite failed", error: e, stackTrace: st);
      }
    }
    
    // ... rest of the method (keeping simple to avoid too much content in one go)
    // Actually I should add more logs to the rest of the method as well.

    if (currentUserAuth == null) {
      AppLogger.d("User still null, checking legacy CacheHelper...");
      // Legacy fallback to CacheHelper
      if (lastUserId != null && lastUserId.isNotEmpty) {
        final String? cachedRaw = await CacheHelper.getData(
          key: CacheHelper.cachedUserDataKey(lastUserId),
          type: "String",
        ) as String?;
        if (cachedRaw != null && cachedRaw.isNotEmpty) {
          try {
            final decoded = jsonDecode(cachedRaw);
            if (decoded is Map) {
              final m = Map<String, dynamic>.from(decoded);
              final email = m['email']?.toString();
              final rid = m['role_id'];
              final Map<String, dynamic>? meta = rid != null ? <String, dynamic>{'role_id': rid} : null;
              currentUserAuth = AppUser(
                id: lastUserId,
                email: email,
                userMetadata: meta,
              );
              primeCurrentUser(currentUserAuth);
              AppLogger.d("Restored user from legacy cache");
            }
          } catch (e, st) {
            AppLogger.e("prepareAuthSession: offline user restore from CacheHelper failed", error: e, stackTrace: st);
          }
        }
      }
    }

    if (currentUserAuth == null) {
      AppLogger.d("Returning anonymous preparation result");
      return AuthSessionPreparationResult(
        categories: currentCategories,
        compoundsLogos: currentLogos,
        myCompounds: {'0': "Add New Community"},
        chatMembers: [],
        membersData: [],
      );
    }

    final String userId = currentUserAuth.id;
    AppLogger.d("Proceeding with userId: $userId");
    Map<String, dynamic> localMyCompounds = {'0': "Add New Community"};
    String? localSelectedCompoundId;

    if (localSession != null) {
      AppLogger.d("Reading compound info from local session");
      localSelectedCompoundId = _coerceToCompoundId(localSession['selected_compound_id']);
      final mcRaw = localSession['my_compounds_json'];
      if (mcRaw != null) {
        try {
          localMyCompounds = _parseMyCompoundsMap(jsonDecode(mcRaw));
        } catch (_) {}
      }
    }

    if (localSelectedCompoundId == null) {
      AppLogger.d("Selected compound null, checking legacy CacheHelper...", tag: 'AuthRepository');
      final String? cachedRaw = await CacheHelper.getData(
        key: CacheHelper.cachedUserDataKey(userId),
        type: "String",
      ) as String?;
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedRaw);
          if (decoded is Map) {
            final m = Map<String, dynamic>.from(decoded);
            localSelectedCompoundId = _coerceToCompoundId(m['selectedCompoundId']);
            final mc = m['myCompounds'];
            if (mc != null) {
              localMyCompounds = _parseMyCompoundsMap(mc);
            }
          }
        } catch (e, st) {
          AppLogger.e("prepareAuthSession: invalid cached user JSON", tag: 'AuthRepository', error: e, stackTrace: st);
        }
      }
    }

    if (localSelectedCompoundId == null) {
      try {
        AppLogger.d("Fetching default compound ID...");
        localSelectedCompoundId = await getDefaultCompoundId(userId);
      } catch (e, st) {
        AppLogger.e("prepareAuthSession: getDefaultCompoundId failed",error:  e, stackTrace: st);
      }
    }

    if (localSelectedCompoundId == null || localSelectedCompoundId.isEmpty) {
      AppLogger.d("Falling back to index from CacheHelper");
      localSelectedCompoundId = _coerceToCompoundId(await CacheHelper.getCompoundCurrentIndex());
    }

    AppLogger.d("Selected compound ID: $localSelectedCompoundId");

    if (localSelectedCompoundId != null && localMyCompounds.length <= 1) {
      try {
        final compound = currentCategories
            .expand((cat) => cat.compounds)
            .firstWhere((c) => c.id == localSelectedCompoundId);
        localMyCompounds = {
          '0': "Add New Community",
          localSelectedCompoundId: compound.name,
        };
        AppLogger.d("Re-mapped myCompounds from global list");
      } catch (_) {}
    }

    AppLogger.d("Resolving user role...");
    final roleFromUserRoles = await _fetchRemoteRoleForUser(userId);
    final roleFromPrefs = _resolveRoleFromRoleId(currentUserAuth.userMetadata?["role_id"]);
    final roleFromLocal = _resolveRoleFromRoleId(localSession?['role_id']);
    final Roles? userRole = roleFromUserRoles ?? roleFromPrefs ?? roleFromLocal;
    AppLogger.d("User role: $userRole");

    if (userRole == null) {
      AppLogger.d("Incomplete profile (role null)");
      return AuthSessionPreparationResult(
        user: currentUserAuth,
        myCompounds: localMyCompounds,
        chatMembers: [],
        membersData: [],
        categories: currentCategories,
        compoundsLogos: currentLogos,
        isProfileIncomplete: true,
      );
    }

    await _persistCachedRoleId(
      userId: userId,
      email: currentUserAuth.email,
      role: userRole,
    );

    List<ChatMember> chatMembers = [];
    List<Users> membersData = [];
    ChatMember? currentUserMember;

    if (localSelectedCompoundId != null) {
      try {
        AppLogger.d("Loading members for compound: $localSelectedCompoundId");
        final result = await loadCompoundMembers(localSelectedCompoundId, role: userRole);
        chatMembers = result.members;
        membersData = result.membersData;
        AppLogger.d("Members loaded: ${chatMembers.length}");

        final uid = currentUserAuth.id.trim();
        if (chatMembers.isNotEmpty) {
          currentUserMember = chatMembers.firstWhere(
            (member) => member.id.trim() == uid,
            orElse: () {
              AppLogger.d("Current user $uid not found in members list");
              return chatMembers.first;
            },
          );
        }
      } catch (e, st) {
        AppLogger.e("prepareAuthSession: loadCompoundMembers failed", error: e, stackTrace: st);
      }
    }

    AppLogger.d("prepareAuthSession complete.");
    return AuthSessionPreparationResult(
      user: currentUserAuth,
      role: userRole,
      selectedCompoundId: localSelectedCompoundId,
      myCompounds: localMyCompounds,
      chatMembers: chatMembers,
      membersData: membersData,
      currentUserMember: currentUserMember,
      categories: currentCategories,
      compoundsLogos: currentLogos,
    );
  }

  String? _coerceToCompoundId(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    final s = value.toString();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  Map<String, dynamic> _parseMyCompoundsMap(dynamic raw) {
    if (raw == null) return {'0': "Add New Community"};
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    return {'0': "Add New Community"};
  }

  /// Resolves role from enum name string (e.g., "manager" -> Roles.manager).
  /// Now that Appwrite enum column exists, all role_id values are canonical enum names.
  Roles? _resolveRoleFromRoleId(dynamic roleRaw) {
    if (roleRaw == null) return null;
    final str = (roleRaw is String) ? roleRaw : roleRaw.toString();
    final t = str.trim();
    if (t.isEmpty) return null;
    final byName = Roles.values.where((r) => r.name == t).toList();
    return byName.isNotEmpty ? byName.first : null;
  }

  /// Converts a Roles enum to its canonical name string (e.g., Roles.manager -> "manager").
  String _roleIdStringForRole(Roles role) => role.name;

  /// Normalizes incoming role_id to canonical enum name string.
  /// Now that Appwrite enum column exists, we only accept valid enum names.
  String? _normalizeRoleIdString(dynamic roleRaw) {
    if (roleRaw == null) return null;
    final str = (roleRaw is String) ? roleRaw : roleRaw.toString();
    final t = str.trim();
    if (t.isEmpty) return null;
    final byName = Roles.values.where((r) => r.name == t).toList();
    return byName.isNotEmpty ? byName.first.name : null;
  }

  Future<Roles?> _fetchRemoteRoleForUser(String userId) async {
    try {
      final result = await _tables.listRows(
        databaseId: appwriteDatabaseId,
        tableId: _kColUserRoles,
        queries: [
          Query.equal('user_id', userId),
          Query.isNull('deleted_at'),
          Query.orderDesc(r'$updatedAt'),
          Query.limit(1),
        ],
      );
      if (result.rows.isEmpty) return null;
      return _resolveRoleFromRoleId(result.rows.first.data['role_id']);
    } catch (e, st) {
      AppLogger.e("_fetchRemoteRoleForUser failed", error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _persistCachedRoleId({
    required String userId,
    required String? email,
    required Roles role,
  }) async {
    final String? cachedRaw = await CacheHelper.getData(
      key: CacheHelper.cachedUserDataKey(userId),
      type: "String",
    ) as String?;
    Map<String, dynamic> m = {};
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is Map) m = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    m['email'] = email ?? '';
    m['role_id'] = _roleIdStringForRole(role);
    await CacheHelper.saveData(
      key: CacheHelper.cachedUserDataKey(userId),
      value: jsonEncode(m),
    );
  }

  // ── Auth operations ────────────────────────────────────────────────────────

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final user = await remoteDataSource.remoteSignInWithPassword(
      email: email,
      password: password,
    );
    _notify(user);
    return user;
  }

  /// Google auth goes through Appwrite's native OAuth2 flow.
  @override
  Future<AppUser?> signInWithGoogle() async {
    final user = await remoteDataSource.remoteSignInWithGoogle();
    _notify(user);
    return user;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    await remoteDataSource.remoteSignUp(
      email: email,
      password: password,
      data: data,
    );
    // Triggers `users.*.update.prefs` → on_user_register (Appwrite function).
    await _remoteUpdateProvisioningPrefs(_mapSignUpDataToPrefs(data));
    // Fetch and cache the newly created user (includes prefs in userMetadata).
    final user = await remoteDataSource.remoteFetchCurrentUser();
    _notify(user);
  }

  @override
  Future<void> signOut() async {
    final uid = _currentUser?.id;
    await remoteDataSource.remoteSignOut();
    if (uid != null) {
      await localDataSource.localDeleteSession(uid);
    }
    // Best-effort native Google session cleanup (mainly Android native sign-in path).
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.signOut();

    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.w("Google signOut cleanup skipped", tag: 'AuthRepository');
      }
    }
    await CacheHelper.removeData(CacheHelper.compoundCurrentIndexKey);
    await CacheHelper.removeData(CacheHelper.lastActiveUserIdKey);
    await CacheHelper.removeData("MyCompounds");
    _notify(null);
  }

  @override
  Future<AppUser?> signInWithGoogleWeb(String idToken) async {
    final user = await remoteDataSource.remoteCompleteWebGoogleLogin(idToken);
    _notify(user);
    return user;
  }

  // ── Profile / account management ─────────────────────────────────────────

  @override
  Future<void> updateProfile({
    required String fullName,
    required String displayName,
    required OwnerTypes ownerType,
    required String phoneNumber,
  }) async {
    final userId = await _fetchAuthenticatedUserId();
    if (userId == null) return;

    // Update the display name on the Appwrite account.
    await _appwriteAccount.updateName(name: displayName);

    final payload = <String, dynamic>{
      'full_name': fullName,
      'display_name': displayName,
      'owner_type': ownerType.name,
      'phone_number': phoneNumber,
    };
    
    // Incrementing version to ensure Last-Write-Wins (LWW) identifies this as the newest update
    await _remoteUpsertDocument(
      collectionId: _kColProfiles,
      documentId: userId,
      data: payload,
    );
  }

  /// Prefs keys consumed by [functions/on_user_register] (users.*.update.prefs).
  /// Expects role_id to be canonical enum name (e.g., "manager").
  Map<String, dynamic> _mapSignUpDataToPrefs(Map<String, dynamic> data) {
    String? getVal(List<String> keys) {
      for (final k in keys) {
        final v = data[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isEmpty) continue;
        return s;
      }
      return null;
    }

    final m = <String, dynamic>{};
    
    // Mapping of registration fields to their possible input keys
    final fieldMappings = {
      'full_name': ['full_name', 'fullName'],
      'display_name': ['display_name', 'displayName'],
      'ownerType': ['ownerType', 'owner_type'],
      'phoneNumber': ['phoneNumber', 'phone_number'],
      'avatar_url': ['avatar_url', 'avatarUrl'],
      'compound_id': ['compound_id', 'compoundId'],
      'building_num': ['building_num', 'buildingNum'],
      'apartment_num': ['apartment_num', 'apartmentNum'],
    };

    fieldMappings.forEach((targetKey, sourceKeys) {
      final value = getVal(sourceKeys);
      if (value != null) m[targetKey] = value;
    });

    // Extract and validate role_id as canonical enum name
    final roleRaw = data['role_id'] ?? data['roleId'];
    final normalizedRoleId = _normalizeRoleIdString(roleRaw);
    if (normalizedRoleId != null) m['role_id'] = normalizedRoleId;

    return m;
  }

  String? _readCurrentUserAvatarUrl() {
    final avatarCandidate = _currentUser?.userMetadata?['avatar_url'];
    if (avatarCandidate == null) return null;
    final avatarUrl = avatarCandidate.toString().trim();
    if (avatarUrl.isEmpty) return null;
    return avatarUrl;
  }

  /// Merges with existing [Account] prefs and writes, so Google OAuth users keep
  /// any prior keys while completing registration.
  Future<void> _remoteUpdateProvisioningPrefs(Map<String, dynamic> next) async {
    if (next.isEmpty) return;
    final merged = await _appwriteAccount.getPrefs();
    final out = Map<String, dynamic>.from(merged.data);
    for (final e in next.entries) {
      if (e.value != null) out[e.key] = e.value;
    }
    await _appwriteAccount.updatePrefs(prefs: out);
  }

  @override
  Future<RegistrationResult> processRegistration({
    required String fullName,
    required String userName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    required String roleId,
    required String buildingName,
    required String apartmentNum,
    required String compoundId,
  }) async {
    final userId = await _fetchAuthenticatedUserId();
    if (userId == null) throw Exception('No authenticated user found');
    final avatarUrl = _readCurrentUserAvatarUrl();

    // Normalize roleId to enum name (canonicalize incoming value)
    final normalizedRoleId = _normalizeRoleIdString(roleId);
    if (normalizedRoleId == null) throw Exception('Invalid role: $roleId');
    final role = _resolveRoleFromRoleId(normalizedRoleId);
    if (role == null) throw Exception('Could not resolve role: $roleId');

    // 1. Update account preferences for backend functions
    // Write the canonical enum name to prefs
    await _remoteUpdateRegistrationPrefs(
      fullName: fullName,
      userName: userName,
      ownerType: ownerType,
      phoneNumber: phoneNumber,
      roleId: normalizedRoleId,
      buildingName: buildingName,
      apartmentNum: apartmentNum,
      compoundId: compoundId,
      avatarUrl: avatarUrl,
    );

    // 2. Ensure profile document exists
    await _remoteEnsureProfileExists(
      userId: userId,
      fullName: fullName,
      displayName: userName,
      ownerType: ownerType,
      phoneNumber: phoneNumber,
      avatarUrl: avatarUrl,
    );

    // 3. Handle role assignment if not default (user)
    if (role != Roles.user) {
      await _remoteHandleUserRole(userId: userId, roleName: normalizedRoleId);
    }

    // 4. Provision building and chat channel
    await _remoteProvisionBuildingAndChannel(
      compoundId: compoundId,
      buildingName: buildingName,
    );

    // 5. Register the user's specific apartment
    await _remoteRegisterUserApartment(
      userId: userId,
      compoundId: compoundId,
      buildingName: buildingName,
      apartmentNum: apartmentNum,
    );

    // Resolve compound name for mapping
    String compoundName = compoundId;
    try {
      final categories = await loadCompounds();
      compoundName = categories
          .expand((c) => c.compounds)
          .firstWhere((co) => co.id == compoundId)
          .name;
    } catch (_) {}

    final myCompounds = {
      '0': "Add New Community",
      compoundId: compoundName,
    };

    // Auto-select the newly registered compound
    await selectCompound(
      compoundId: compoundId,
      compoundName: compoundName,
      atWelcome: true,
    );

    return RegistrationResult(
      role: role,
      selectedCompoundId: compoundId,
      compoundName: compoundName,
      myCompounds: myCompounds,
    );
  }

  @override
  Future<void> uploadVerificationFiles({
    required List<XFile> files,
    required String userId,
    required void Function(int index, double progress) onProgress,
  }) async {
    await remoteDataSource.remoteUploadVerificationFiles(
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
    final res = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColUserApartments,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('building_num', buildingName),
        Query.equal('apartment_num', apartmentNum),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );
    return res.rows.isNotEmpty;
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
    } catch (e, st) {
      if (kDebugMode) {
        AppLogger.e("getDefaultCompoundId failed", tag: 'AuthRepository', error: e, stackTrace: st);
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
      AppLogger.d(
        "selectCompound: saving compoundId=$compoundId name=\"$compoundName\" atWelcome=$atWelcome (CacheHelper + MyCompounds JSON)",
        tag: 'AuthRepository',
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

  @override
  Future<void> saveLocalSession() async {
    final user = _currentUser;
    if (user == null) return;

    final compoundId = await CacheHelper.getCompoundCurrentIndex();
    final myCompoundsRaw = await CacheHelper.getData(key: "MyCompounds", type: "String") as String?;
    Map<String, dynamic> myCompounds = {'0': "Add New Community"};
    if (myCompoundsRaw != null) {
      try {
        myCompounds = _parseMyCompoundsMap(jsonDecode(myCompoundsRaw));
      } catch (_) {}
    }

    final roleId = user.userMetadata?['role_id'];
    final rId = _normalizeRoleIdString(roleId);

    await localDataSource.localSaveSession(
      userId: user.id,
      email: user.email,
      userMetadata: user.userMetadata,
      selectedCompoundId: compoundId,
      myCompounds: myCompounds,
      roleId: rId,
    );
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
  Future<List<Category>> loadCompounds({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null && _cachedCategories!.isNotEmpty) {
      return _cachedCategories!;
    }
    final result = await _loadCompoundsFromAppwrite();
    _cachedCategories = result;
    return result;
  }

  Future<List<Category>> _loadCompoundsFromAppwrite() async {
    AppLogger.d("Listing categories from table $_kColCompoundCategories...");
    final catDocs = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColCompoundCategories,
      queries: [
        Query.isNull('deleted_at'),
        Query.orderAsc('name'),
        Query.limit(500),
      ],
    ).timeout(const Duration(seconds: 15));
    AppLogger.d("Categories received: ${catDocs.rows.length}");

    AppLogger.d("Listing compounds from table $_kColCompounds...");
    final compoundDocs = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColCompounds,
      queries: [Query.isNull('deleted_at'), Query.limit(5000)],
    ).timeout(const Duration(seconds: 15));
    AppLogger.d("Compounds received: ${compoundDocs.rows.length}");

    if (kDebugMode) {
      AppLogger.d(
        "loadCompounds listRows: databaseId=$appwriteDatabaseId "
        "categoriesTable=$_kColCompoundCategories compoundsTable=$_kColCompounds "
        "→ ${catDocs.rows.length} category row(s), ${compoundDocs.rows.length} compound row(s)",
      );
    }

    // Client listRows is permission-scoped. Console "sees" all rows; the mobile
    // client only sees rows where the table allows Read for the current session
    // (e.g. role "users") or for guests ("any") during signup.
    if (kDebugMode && (catDocs.rows.isEmpty || compoundDocs.rows.isEmpty)) {
      try {
        final u = await _appwriteAccount.get();
        AppLogger.d(
          "loadCompounds: listRows is empty but a session exists (userId=${u.$id}). If the console shows rows, add Read permissions on tables $_kColCompoundCategories & $_kColCompounds for Users (or Any if this screen runs before sign-in).",
          tag: 'AuthRepository',
        );
      } on AppwriteException catch (e) {
        if (e.code == 401) {
          AppLogger.d(
            "loadCompounds: no Appwrite session (401). listRows for compounds is empty. Either sign in first, or add table Read=**Any** for the community list during signup, then tighten later.",
            tag: 'AuthRepository',
          );
        } else {
          AppLogger.d(
            "loadCompounds: could not read session: ${e.message}",
            tag: 'AuthRepository',
          );
        }
      } catch (e, st) {
        AppLogger.e("loadCompounds: session check failed", tag: 'AuthRepository', error: e, stackTrace: st);
      }
    }

    AppLogger.d("Starting isolate compute for compounds...", tag: 'AuthRepository');
    final parsed =
        await compute(parseAppwriteCompoundsForIsolate, <String, dynamic>{
          'categories': catDocs.rows.map((r) => r.toMap()).toList(),
          'compounds': compoundDocs.rows.map((r) => r.toMap()).toList(),
        });
    AppLogger.d("Isolate compute finished.", tag: 'AuthRepository');

    if (kDebugMode) {
      final total = parsed.fold<int>(0, (sum, c) => sum + c.compounds.length);
      AppLogger.d(
        "loadCompounds after compute: ${parsed.length} category bucket(s), $total compound(s) in tree (UI categories may include \"Other\" for unmatched)",
        tag: 'AuthRepository',
      );
    }

    return parsed;
  }

  @override
  Future<CompoundMembersResult> loadCompoundMembers(String compoundId,
      {Roles? role}) async {
    // 1. Load from local cache for instant UI
    final cached = await localDataSource.localFetchMembers(compoundId);
    
    // 2. Trigger delta-sync in background to fetch newcomers
    // This will update SQLite and the local sync timestamp.
    final syncResult = await _syncMembersFromRemote(compoundId);
    
    // If sync added new members, we fetch again to return the full list.
    final finalMembers = syncResult.isNotEmpty 
        ? await localDataSource.localFetchMembers(compoundId)
        : cached;

    return CompoundMembersResult(
      members: finalMembers,
      membersData: finalMembers.map((m) => Users(
        authorId: m.id,
        phoneNumber: m.phoneNumber,
        updatedAt: DateTime.now(), 
        ownerShipType: m.ownerType?.name ?? '',
        userState: m.userState?.name ?? '',
        actionTakenBy: '',
        verFile: [],
      )).toList(),
    );
  }

  Future<List<ChatMember>> _syncMembersFromRemote(String compoundId) async {
    try {
      final lastSync = await localDataSource.localGetMembersLastSync(compoundId);
      final rawDelta = await remoteDataSource.remoteFetchMembersDelta(
        compoundId: compoundId,
        sinceIso: lastSync,
      );

      if (rawDelta.isEmpty) return [];

      final deltaMembers = rawDelta.map((m) => ChatMember.fromJson(m)).toList();
      await localDataSource.localUpsertMembers(compoundId, deltaMembers);
      
      // Update sync timestamp to now (Appwrite uses $updatedAt)
      await localDataSource.localUpdateMembersLastSync(
        compoundId, 
        DateTime.now().toUtc().toIso8601String(),
      );
      
      return deltaMembers;
    } catch (e, st) {
      AppLogger.e("_syncMembersFromRemote failed", tag: 'AuthRepository', error: e, stackTrace: st);
      return [];
    }
  }

  /// Attempts to update an existing row, or creates it if not found (404).
  Future<void> _remoteUpsertDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _tables.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: collectionId,
        rowId: documentId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Incrementing version to ensure Last-Write-Wins (LWW) identifies this as the newest update
        await _tables.createRow(
          databaseId: appwriteDatabaseId,
          tableId: collectionId,
          rowId: documentId,
          data: <String, dynamic>{...data, 'version': 0},
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _remoteUpdateRegistrationPrefs({
    required String fullName,
    required String userName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    required String roleId,
    required String buildingName,
    required String apartmentNum,
    required String compoundId,
    String? avatarUrl,
  }) async {
    final provisioningPayload = {
      'full_name': fullName,
      'display_name': userName,
      'ownerType': ownerType.name,
      'phoneNumber': phoneNumber,
      'role_id': roleId,
      'compound_id': compoundId,
      'building_num': buildingName,
      'apartment_num': apartmentNum,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    await _remoteUpdateProvisioningPrefs(provisioningPayload);
  }

  Future<void> _remoteEnsureProfileExists({
    required String userId,
    required String fullName,
    required String displayName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    String? avatarUrl,
  }) async {
    final profilePayload = <String, dynamic>{
      'full_name': fullName,
      'display_name': displayName,
      'owner_type': ownerType.name,
      'phone_number': phoneNumber,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    await _remoteUpsertDocument(
      collectionId: _kColProfiles,
      documentId: userId,
      data: profilePayload,
    );
  }

  Future<void> _remoteHandleUserRole({
    required String userId,
    required String roleName,
  }) async {
    try {
      // Write the canonical enum name (e.g., "manager") to the enum column
      await _remoteUpsertDocument(
        collectionId: _kColUserRoles,
        documentId: userId,
        data: {'user_id': userId, 'role_id': roleName},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _remoteProvisionBuildingAndChannel({
    required String compoundId,
    required String buildingName,
  }) async {
    final buildings = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColBuildings,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('building_name', buildingName),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );

    late final String buildingDocId;
    if (buildings.rows.isEmpty) {
      final created = await _tables.createRow(
        databaseId: appwriteDatabaseId,
        tableId: _kColBuildings,
        rowId: ID.unique(),
        data: {
          'compound_id': compoundId,
          'building_name': buildingName,
          'version': 0,
        },
      );
      buildingDocId = created.$id;
    } else {
      buildingDocId = buildings.rows.first.$id;
    }

    final channels = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColChannels,
      queries: [
        Query.equal('compound_id', compoundId),
        Query.equal('building_id', buildingDocId),
        Query.equal('type', 'BUILDING_CHAT'),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );
    if (channels.rows.isEmpty) {
      await _tables.createRow(
        databaseId: appwriteDatabaseId,
        tableId: _kColChannels,
        rowId: ID.unique(),
        data: {
          'compound_id': compoundId,
          'building_id': buildingDocId,
          'name': 'Building $buildingName Chat',
          'type': 'BUILDING_CHAT',
          'version': 0,
        },
      );
    }
    return buildingDocId;
  }

  Future<void> _remoteRegisterUserApartment({
    required String userId,
    required String compoundId,
    required String buildingName,
    required String apartmentNum,
  }) async {
    final existingMine = await _tables.listRows(
      databaseId: appwriteDatabaseId,
      tableId: _kColUserApartments,
      queries: [
        Query.equal('user_id', userId),
        Query.equal('compound_id', compoundId),
        Query.equal('building_num', buildingName),
        Query.equal('apartment_num', apartmentNum),
        Query.isNull('deleted_at'),
        Query.limit(1),
      ],
    );
    if (existingMine.rows.isEmpty) {
      await _tables.createRow(
        databaseId: appwriteDatabaseId,
        tableId: _kColUserApartments,
        rowId: ID.unique(),
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
}
