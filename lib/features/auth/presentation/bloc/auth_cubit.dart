import 'dart:async';
import 'dart:convert';
import 'package:WhatsUnity/core/config/runtime_env.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode ,kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/appwrite.dart';
import '../../../../core/config/app_directory_types.dart' show Users;
import '../../../../core/constants/Constants.dart';
import '../../../../core/models/CompoundsList.dart';
import '../../../../core/network/CacheHelper.dart';
import '../../../chat/data/models/chat_member_model.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository repository;

  // UI state moved from AppCubit
  bool isPassword = true;
  IconData suffixIcon = Icons.visibility_off;
  bool signInToggler = true;
  OwnerTypes ownerType = OwnerTypes.owner;
  String? signupGoogleEmail;
  String? signupGoogleUserName;
  bool signInGoogle = false;
  int authSessionNonce = DateTime.now().microsecondsSinceEpoch;

  bool signingIn = false;
  bool googleSigningIn = false;
  List<XFile>? verFiles;
  final List<double> uploadProgress = [];
  bool apartmentConflict = false;

  List<Category> compoundSuggestions = [];

  /// Prevents re-entrant [loadCompounds] when UI calls it from [build] (infinite AuthLoading loop).
  bool _loadCompoundsInProgress = false;

  Roles? roleName;
  String? selectedCompoundId;
  Map<String, dynamic> myCompounds = {'0': "Add New Community"};

  AuthCubit({required this.repository}) : super(AuthInitial()) {


    if (kIsWeb) {
      // 1. Initialize the singleton with your Web Client ID
      GoogleSignIn.instance.initialize(clientId: RuntimeEnv.googleServerClientId);

      // 2. Listen to the new v7 event stream!
      GoogleSignIn.instance.authenticationEvents.listen((event) async {

        // Check if the event is a successful login
        if (event is GoogleSignInAuthenticationEventSignIn) {
          try {
            print("🚀 [WEB GOOGLE] Account caught! Fetching token...");

            // Extract the user account from the new event object
            final account = event.user;
            final auth = await account.authentication;

            if (auth.idToken != null) {
              print("🚀 [WEB GOOGLE] Token found! Sending to backend bridge...");
              await repository.completeWebGoogleLogin(auth.idToken!);
              print("🚀 [WEB GOOGLE] Bridge complete!");
            }
          } catch (e) {
            print("❌ [WEB GOOGLE] SILENT CRASH: $e");
          }
        }
      });

      // 3. Kickstart using the new v7 lightweight method!
    // --- THE FIX: PROPER ASYNC ERROR CATCHING ---
    GoogleSignIn.instance.attemptLightweightAuthentication()?.catchError((error) {
    // This safely swallows the FedCM 'canceled' error so Dart doesn't crash!
    print("ℹ️ [WEB GOOGLE] Lightweight auth skipped (Normal behavior): $error");
    });
    }
    // Listen to the Appwrite-backed auth stream.
    // Emits AppUser? — non-null means signed in, null means signed out.
    repository.onAuthStateChange.listen(
      (appUser) {
        try {
          if (appUser != null) {
            final isProfileIncomplete = appUser.userMetadata == null || appUser.userMetadata!['role_id'] == null;

            if (isProfileIncomplete) {
              // FORCE them to the completion form instead of logging them in!
              signupGoogleEmail = appUser.email;
              signupGoogleUserName = appUser.userMetadata?['full_name'] ?? appUser.userMetadata?['name'];
              signInToggler = false;
              emit(GoogleSignupState());
              return;
            }
            _attachRealtimeUserObservers(appUser.id);
            authSessionNonce = DateTime.now().microsecondsSinceEpoch;
            if (state is Authenticated) {
              // Preserve all loaded data (chatMembers, compounds, etc.);
              // only refresh the user object itself.
              emit((state as Authenticated).copyWith(user: appUser));
            } else {
              emit(Authenticated(
                user: appUser,
                enabledMultiCompound: enabledMultiCompound,
                googleUser: googleUser,
                categories: state.categories,
                compoundsLogos: state.compoundsLogos,
              ));
            }
          } else {
            _detachRealtimeUserObservers();
            authSessionNonce = DateTime.now().microsecondsSinceEpoch;
            signInToggler = true;
            emit(Unauthenticated(
              categories: state.categories,
              compoundsLogos: state.compoundsLogos,
            ));
          }
        } catch (e, st) {
          debugPrint('[AuthCubit] onAuthStateChange handler failed: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[AuthCubit] onAuthStateChange stream error: $e\n$st');
      },
    );
  }

  bool enabledMultiCompound = false;
  GoogleSignInAccount? googleUser;
  Future<void>? _presetBeforeSigninInFlight;
  bool _isSigningOut = false;
  RealtimeSubscription? _profilesRealtimeSubscription;
  RealtimeSubscription? _userRolesRealtimeSubscription;
  String? _realtimeObservedUserId;
  bool _refreshFromRealtimeInProgress = false;

  Future<void> _persistCachedRoleId({
    required String userId,
    required String? email,
    required Roles role,
  }) async {
    try {
      final cacheKey = CacheHelper.cachedUserDataKey(userId);
      final existingRaw =
          await CacheHelper.getData(key: cacheKey, type: "String") as String?;
      Map<String, dynamic> cached = <String, dynamic>{};
      if (existingRaw != null && existingRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(existingRaw);
          if (decoded is Map) {
            cached = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          cached = <String, dynamic>{};
        }
      }
      cached['email'] = email ?? (cached['email'] ?? '');
      cached['role_id'] = role.index + 1;
      await CacheHelper.saveData(key: cacheKey, value: jsonEncode(cached));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthCubit] _persistCachedRoleId failed: $e');
      }
    }
  }

  Roles? _resolveRoleFromRoleId(dynamic roleRaw) {
    if (roleRaw == null) return null;
    final roleId = roleRaw is int ? roleRaw : int.tryParse(roleRaw.toString());
    if (roleId == null || roleId <= 0 || roleId > Roles.values.length) {
      return null;
    }
    return Roles.values[roleId - 1];
  }

  Future<Roles?> _fetchRemoteRoleForUser(String userId) async {
    try {
      final result = await appwriteTables.listRows(
        databaseId: appwriteDatabaseId,
        tableId: 'user_roles',
        queries: [
          Query.equal('user_id', userId),
          Query.isNull('deleted_at'),
          Query.orderDesc(r'$updatedAt'),
          Query.limit(1),
        ],
      );
      if (result.rows.isEmpty) return null;
      return _resolveRoleFromRoleId(result.rows.first.data['role_id']);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthCubit] _fetchRemoteRoleForUser failed: $e');
      }
      return null;
    }
  }

  Future<void> _refreshAuthenticatedStateFromRemote() async {
    if (_refreshFromRealtimeInProgress) return;
    _refreshFromRealtimeInProgress = true;
    try {
      final refreshedUser = await repository.fetchCurrentUser();
      if (refreshedUser == null) return;

      final roleFromUserRoles = await _fetchRemoteRoleForUser(refreshedUser.id);
      final roleFromPrefs = _resolveRoleFromRoleId(
        refreshedUser.userMetadata?['role_id'],
      );
      // Source of truth for runtime authorization is `user_roles`.
      // Prefs can lag behind and must not override a fresh role change.
      final resolvedRole = roleFromUserRoles ?? roleFromPrefs;
      if (resolvedRole != null) {
        await _persistCachedRoleId(
          userId: refreshedUser.id,
          email: refreshedUser.email,
          role: resolvedRole,
        );
      }

      final activeState = state;
      final selectedCompoundId =
          activeState is Authenticated ? activeState.selectedCompoundId : null;

      List<ChatMember> refreshedMembers = const [];
      List<Users> refreshedMembersData = const [];
      ChatMember? refreshedCurrentMember;
      if (selectedCompoundId != null && selectedCompoundId.isNotEmpty) {
        try {
          final membersResult = await repository.loadCompoundMembers(
            selectedCompoundId,
            role: resolvedRole,
          );
          refreshedMembers = membersResult.members;
          refreshedMembersData = membersResult.membersData;
          refreshedCurrentMember = refreshedMembers.firstWhere(
            (member) => member.id.trim() == refreshedUser.id.trim(),
            orElse: () => refreshedMembers.isNotEmpty
                ? refreshedMembers.first
                : throw StateError('No members found'),
          );
        } catch (_) {
          refreshedCurrentMember = null;
        }
      }

      if (activeState is Authenticated) {
        emit(activeState.copyWith(
          user: refreshedUser,
          role: resolvedRole,
          chatMembers: refreshedMembers,
          membersData: refreshedMembersData,
          currentUser: refreshedCurrentMember,
          timestamp: DateTime.now().microsecondsSinceEpoch,
        ));
      } else {
        emit(Authenticated(
          user: refreshedUser,
          role: resolvedRole,
          chatMembers: refreshedMembers,
          membersData: refreshedMembersData,
          currentUser: refreshedCurrentMember,
          timestamp: DateTime.now().microsecondsSinceEpoch,
        ));
      }
    } catch (e, st) {
      debugPrint(
        '[AuthCubit] _refreshAuthenticatedStateFromRemote failed: $e\n$st',
      );
    } finally {
      _refreshFromRealtimeInProgress = false;
    }
  }

  void _attachRealtimeUserObservers(String userId) {
    if (_realtimeObservedUserId == userId &&
        _profilesRealtimeSubscription != null &&
        _userRolesRealtimeSubscription != null) {
      return;
    }
    _detachRealtimeUserObservers();
    _realtimeObservedUserId = userId;

    try {
      final profileChannels = <String>[
        'databases.$appwriteDatabaseId.collections.profiles.documents.$userId',
      ];
      _profilesRealtimeSubscription =
          appwriteRealtime.subscribe(profileChannels);
      _profilesRealtimeSubscription!.stream.listen(
        (_) {
          unawaited(_refreshAuthenticatedStateFromRemote());
        },
        onError: (Object e, StackTrace st) {
          debugPrint('[AuthCubit] profiles realtime stream error: $e\n$st');
        },
      );

      final userRoleChannels = <String>[
        'databases.$appwriteDatabaseId.collections.user_roles.documents',
        'databases.$appwriteDatabaseId.tables.user_roles.rows',
      ];
      _userRolesRealtimeSubscription =
          appwriteRealtime.subscribe(userRoleChannels);
      _userRolesRealtimeSubscription!.stream.listen(
        (message) {
          try {
            final payload = Map<String, dynamic>.from(message.payload);
            final eventUserId = (payload['user_id'] ?? payload[r'$id'] ?? '')
                .toString()
                .trim();
            if (eventUserId != userId) return;

            final roleFromPayload = _resolveRoleFromRoleId(payload['role_id']);
            if (roleFromPayload != null && state is Authenticated) {
              final currentState = state as Authenticated;
              unawaited(
                _persistCachedRoleId(
                  userId: currentState.user.id,
                  email: currentState.user.email,
                  role: roleFromPayload,
                ),
              );
              emit((state as Authenticated).copyWith(
                role: roleFromPayload,
                timestamp: DateTime.now().microsecondsSinceEpoch,
              ));
            }
            unawaited(_refreshAuthenticatedStateFromRemote());
          } catch (e, st) {
            debugPrint(
              '[AuthCubit] user_roles realtime message handler failed: $e\n$st',
            );
          }
        },
        onError: (Object e, StackTrace st) {
          debugPrint('[AuthCubit] user_roles realtime stream error: $e\n$st');
        },
      );
    } catch (e, st) {
      debugPrint('[AuthCubit] _attachRealtimeUserObservers failed: $e\n$st');
      _detachRealtimeUserObservers();
      _realtimeObservedUserId = null;
    }
  }

  void _detachRealtimeUserObservers() {
    _profilesRealtimeSubscription?.close();
    _profilesRealtimeSubscription = null;
    _userRolesRealtimeSubscription?.close();
    _userRolesRealtimeSubscription = null;
    _realtimeObservedUserId = null;
  }

  void togglePasswordVisibility() {
    isPassword = !isPassword;
    suffixIcon = isPassword ? Icons.visibility_off : Icons.visibility;
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith());
    } else if (state is Unauthenticated) {
      emit(Unauthenticated(
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    } else {
      emit(AuthInitial(
          categories: state.categories, compoundsLogos: state.compoundsLogos));
    }
  }

  void toggleSignIn() {
    signInToggler = !signInToggler;
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith());
    } else if (state is Unauthenticated) {
      emit(Unauthenticated(
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    } else {
      emit(AuthInitial(
          categories: state.categories, compoundsLogos: state.compoundsLogos));
    }
  }

  void changeRole(Roles? newRole) {
    roleName = newRole ?? Roles.user;
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith(role: roleName));
    } else {
      emit(AuthInitial());
    }
  }

  void updateMember(ChatMember updatedMember) {
    if (state is Authenticated) {
      final s = state as Authenticated;
      final members = List<ChatMember>.from(s.chatMembers);
      final index = members.indexWhere((m) => m.id == updatedMember.id);
      if (index != -1) {
        members[index] = updatedMember;

        ChatMember? current = s.currentUser;
        if (current?.id == updatedMember.id) {
          current = updatedMember;
        }

        emit(s.copyWith(chatMembers: members, currentUser: current));
      }
    }
  }

  void updateRole(Roles role) {
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith(role: role));
    }
  }

  void changeOwnerType(OwnerTypes newType) {
    ownerType = newType;
    emit(AuthInitial());
  }

  void signInSwitcher() {
    signingIn = !signingIn;
    emit(AuthInitial());
  }

  void googleSignInSwitcher() {
    googleSigningIn = !googleSigningIn;
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith());
    } else if (state is Unauthenticated) {
      emit(Unauthenticated(
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    } else {
      emit(AuthInitial(
          categories: state.categories, compoundsLogos: state.compoundsLogos));
    }
  }

  Future<void> verFileImport() async {
    final List<XFile> result = await ImagePicker().pickMultiImage(
      imageQuality: 70,
      maxWidth: 1440,
    );

    if (result.isEmpty) return;

    verFiles = result;
    emit(AuthInitial());
  }

  void clearVerFiles() {
    verFiles = null;
    emit(AuthInitial());
  }

  Future<void> verificationFilesUpload() async {
    if (verFiles == null || verFiles!.isEmpty) return;

    emit(AuthLoading());
    try {
      final s = state;
      // Prefer the Authenticated state's user; fall back to cached repository user.
      final userId = (s is Authenticated)
          ? s.user.id
          : repository.currentUser?.id;
      if (userId == null) throw Exception("User ID not found");

      await repository.uploadVerificationFiles(
        files: verFiles!,
        userId: userId,
        onProgress: (index, progress) {
          if (uploadProgress.length <= index) {
            uploadProgress.add(progress);
          } else {
            uploadProgress[index] = progress;
          }
          emit(AuthInitial());
        },
      );
      emit(AuthInitial());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> isApartmentTaken({
    required String compoundId,
    required String buildingName,
    required String apartmentNum,
  }) async {
    try {
      final taken = await repository.isApartmentTaken(
        compoundId: compoundId,
        buildingName: buildingName,
        apartmentNum: apartmentNum,
      );
      apartmentConflict = taken;
      emit(ApartmentTakenStatus(isTaken: taken));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> resetUserData() async {
    emit(AuthInitial());
  }

  Future<void> selectCompound({
    required String compoundId,
    required String compoundName,
    required bool atWelcome,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[AuthCubit] selectCompound: id=$compoundId name="$compoundName" '
          'atWelcome=$atWelcome state=${state.runtimeType}',
        );
      }
      selectedCompoundId = compoundId;
      if (atWelcome) {
        myCompounds = {
          '0': "Add New Community",
          compoundId: compoundName,
        };
      } else {
        myCompounds[compoundId] = compoundName;
      }

      await repository.selectCompound(
        compoundId: compoundId,
        compoundName: compoundName,
        atWelcome: atWelcome,
      );

      if (state is Authenticated) {
        emit((state as Authenticated).copyWith(
          selectedCompoundId: compoundId,
          myCompounds: Map<String, dynamic>.from(myCompounds),
        ));
        if (kDebugMode) {
          debugPrint(
            '[AuthCubit] selectCompound: done → Authenticated(selectedCompoundId=$compoundId)',
          );
        }
      } else {
        emit(CompoundSelected(compoundId));
        if (kDebugMode) {
          debugPrint(
            '[AuthCubit] selectCompound: done → CompoundSelected($compoundId)',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthCubit] selectCompound: ERROR $e');
      }
      emit(AuthError(e.toString()));
    }
  }

  /// Restores [selectedCompoundId] from cached JSON (legacy int or Appwrite String).
  String? _coerceToCompoundId(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    final s = value.toString();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  Map<String, dynamic> _parseMyCompoundsMap(dynamic raw) {
    if (raw == null) return {'0': "Add New Community"};
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return {'0': "Add New Community"};
  }

  /// Snapshots the signed-in user's compound data before sign-out so that
  /// presetBeforeSignin can restore it on next login without a network round-trip.
  Future<void> _cacheUserSnapshotOnSignOut() async {
    // Read identity from the current Authenticated state instead of from
    // supabase.auth.currentUser — the Appwrite session is authoritative now.
    if (state is! Authenticated) return;
    final user = (state as Authenticated).user;

    final Map<String, dynamic> compounds = Map<String, dynamic>.from(
      (state as Authenticated).myCompounds,
    );
    final String? compoundId = (state as Authenticated).selectedCompoundId;

    final payload = <String, dynamic>{
      'email': user.email ?? '',
      'selectedCompoundId': compoundId,
      'myCompounds': compounds,
      if (user.userMetadata?['role_id'] != null)
        'role_id': user.userMetadata!['role_id'],
    };

    await CacheHelper.saveData(
      key: CacheHelper.cachedUserDataKey(user.id),
      value: jsonEncode(payload),
    );
  }

  Future<void> presetBeforeSignin() async {
    final inFlight = _presetBeforeSigninInFlight;
    if (inFlight != null) return inFlight;

    final future = _presetBeforeSigninImpl();
    _presetBeforeSigninInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_presetBeforeSigninInFlight, future)) {
        _presetBeforeSigninInFlight = null;
      }
    }
  }

  Future<void> _presetBeforeSigninImpl() async {
    emit(AuthLoading(
        categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      List<Category> currentCategories = state.categories;
      List<String> currentLogos = state.compoundsLogos;

      if (currentCategories.isEmpty) {
        try {
          currentCategories = await repository.loadCompounds();
        } catch (e, st) {
          debugPrint(
            '[AuthCubit] presetBeforeSignin: loadCompounds failed (offline?): $e\n$st',
          );
          currentCategories = state.categories;
        }
      }
      if (currentLogos.isEmpty) {
        currentLogos = await AssetHelper.loadCompoundLogos();
      }

      // Use repository.fetchCurrentUser() so we get the Appwrite session
      // even when the constructor's _checkExistingSession is still in-flight.
      AppUser? currentUserAuth;
      try {
        currentUserAuth = await repository.fetchCurrentUser();
      } catch (e, st) {
        debugPrint(
          '[AuthCubit] presetBeforeSignin: fetchCurrentUser failed (offline?): $e\n$st',
        );
        currentUserAuth = null;
      }

      if (currentUserAuth == null) {
        final lastUserId = await CacheHelper.getLastActiveUserId();
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
                final Map<String, dynamic>? meta =
                    rid != null ? <String, dynamic>{'role_id': rid} : null;
                currentUserAuth = AppUser(
                  id: lastUserId,
                  email: email,
                  userMetadata: meta,
                );
                repository.primeCurrentUser(currentUserAuth);
              }
            } catch (e) {
              debugPrint(
                'presetBeforeSignin: offline user restore from cache failed ($e)',
              );
            }
          }
        }
      }

      if (currentUserAuth == null) {
        emit(Unauthenticated(
          categories: currentCategories,
          compoundsLogos: currentLogos,
        ));
        return;
      }
      final String userId = currentUserAuth.id;

      Map<String, dynamic> localMyCompounds = {'0': "Add New Community"};
      String? localSelectedCompoundId;

      // 1) Prefer per-user snapshot from last sign-out.
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
        } catch (e) {
          debugPrint(
              'presetBeforeSignin: invalid cached user JSON, using fallback ($e)');
        }
      }

      // 2) Fallback: user_apartments in Appwrite (string user_id + compound_id).
      if (localSelectedCompoundId == null) {
        try {
          localSelectedCompoundId =
              await repository.getDefaultCompoundId(userId);
        } catch (e, st) {
          debugPrint(
            '[AuthCubit] presetBeforeSignin: getDefaultCompoundId failed: $e\n$st',
          );
        }
      }

      // 3) Device-local last compound ([CacheHelper.saveCompoundCurrentIndex]).
      if (localSelectedCompoundId == null || localSelectedCompoundId.isEmpty) {
        localSelectedCompoundId = _coerceToCompoundId(
          await CacheHelper.getCompoundCurrentIndex(),
        );
      }

      // 4) Resolve compound label from loaded categories when only default row exists.
      if (localSelectedCompoundId != null && localMyCompounds.length <= 1) {
        try {
          final compound = currentCategories
              .expand((cat) => cat.compounds)
              .firstWhere((c) => c.id == localSelectedCompoundId);
          localMyCompounds = {
            '0': "Add New Community",
            localSelectedCompoundId: compound.name.toString(),
          };
          await CacheHelper.saveData(
            key: CacheHelper.cachedUserDataKey(userId),
            value: jsonEncode({
              'email': currentUserAuth.email ?? '',
              'selectedCompoundId': localSelectedCompoundId,
              'myCompounds': localMyCompounds,
            }),
          );
        } catch (_) {
          // Compound not found in categories — skip label resolution.
        }
      }

      final roleFromUserRoles = await _fetchRemoteRoleForUser(userId);
      final roleFromPrefs = _resolveRoleFromRoleId(
        currentUserAuth.userMetadata?["role_id"],
      );
      final Roles? userRole = roleFromUserRoles ?? roleFromPrefs;
      if (userRole == null) {
        // The profile is incomplete! Stop all loading and show the form.
        signupGoogleEmail = currentUserAuth.email;
        signupGoogleUserName = currentUserAuth.userMetadata?['full_name'] ?? currentUserAuth.userMetadata?['name'];
        emit(GoogleSignupState());
        return;
      }

      await _persistCachedRoleId(
        userId: userId,
        email: currentUserAuth.email,
        role: userRole,
      );


      List<ChatMember> chatMembers = [];
      List<Users> membersData = [];
      ChatMember? currentUser;

      if (localSelectedCompoundId != null) {
        selectedCompoundId = localSelectedCompoundId;
        myCompounds = localMyCompounds;

        try {
          final result = await repository.loadCompoundMembers(
            localSelectedCompoundId,
            role: userRole,
          );
          chatMembers = result.members;
          membersData = result.membersData;

          final currentUserId = (state is Authenticated)
              ? (state as Authenticated).user.id
              : repository.currentUser?.id;
          if (chatMembers.isEmpty) {
            currentUser = null;
          } else {
            final uid = currentUserId?.trim() ?? '';
            currentUser = chatMembers.firstWhere(
              (member) => member.id.trim() == uid,
              orElse: () => chatMembers.first,
            );
          }
        } catch (e, st) {
          debugPrint(
            '[AuthCubit] presetBeforeSignin: loadCompoundMembers failed (offline?): $e\n$st',
          );
          chatMembers = [];
          membersData = [];
          currentUser = null;
        }
      }

      if (state is Authenticated) {
        emit((state as Authenticated).copyWith(
          role: userRole,
          selectedCompoundId: localSelectedCompoundId,
          myCompounds: localMyCompounds,
          chatMembers: chatMembers,
          membersData: membersData,
          currentUser: currentUser,
          enabledMultiCompound: enabledMultiCompound,
          googleUser: googleUser,
          categories: currentCategories,
          compoundsLogos: currentLogos,
        ));
      } else {
        final currentSessionUser = repository.currentUser;
        if (currentSessionUser != null) {
          emit(Authenticated(
            user: currentSessionUser,
            role: userRole,
            selectedCompoundId: localSelectedCompoundId,
            myCompounds: localMyCompounds,
            chatMembers: chatMembers,
            membersData: membersData,
            currentUser: currentUser,
            enabledMultiCompound: enabledMultiCompound,
            googleUser: googleUser,
            categories: currentCategories,
            compoundsLogos: currentLogos,
          ));
        } else {
          emit(Unauthenticated(
            categories: currentCategories,
            compoundsLogos: currentLogos,
          ));
        }
      }
    } catch (e) {
      debugPrint("Error in presetBeforeSignin: $e");
      emit(AuthError(e.toString(),
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final user =
          await repository.signInWithPassword(email: email, password: password);
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    emit(AuthLoading());
    try {
      await repository.signUp(email: email, password: password, data: data);
      emit(SignUpSuccess(email: email));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signInWithGoogle({bool isSignin = false}) async {
    emit(AuthLoading());
    try {
      signInGoogle = !isSignin;
      final user = await repository.signInWithGoogle();
      if (user != null) {
        if (isSignin) {
          signInGoogle = false;
          emit(Authenticated(user: user));
        } else {
          signupGoogleEmail = user.email;
          signupGoogleUserName =
              user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
          emit(GoogleSignupState());
        }
      } else {
        signInGoogle = false;
        emit(Unauthenticated());
      }
    } catch (e) {
      signInGoogle = false;
      emit(AuthError(e.toString()));
    } finally {
      googleSigningIn = false;
    }
  }

  Future<void> signOut() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    emit(AuthLoading(
        categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      // Snapshot compound data before the session is destroyed.
      await _cacheUserSnapshotOnSignOut();
      await repository.signOut();
    } catch (e) {
      emit(AuthError(e.toString(),
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    } finally {
      _isSigningOut = false;
    }
  }

  Future<void> cancelPendingGoogleRegistration() async {
    emit(AuthLoading(
        categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      await repository.signOut();
      signInGoogle = false;
      signInToggler = true;
      signupGoogleEmail = null;
      signupGoogleUserName = null;
      roleName = Roles.user;
      selectedCompoundId = null;
      myCompounds = {'0': "Add New Community"};
      ownerType = OwnerTypes.owner;
      apartmentConflict = false;
      verFiles = null;
      signingIn = false;
      googleSigningIn = false;
      emit(Unauthenticated(
        categories: state.categories,
        compoundsLogos: state.compoundsLogos,
      ));
    } catch (e) {
      emit(AuthError(e.toString(),
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    }
  }

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
    final categoriesBefore = state.categories;
    emit(AuthLoading());
    try {
      await repository.completeRegistration(
        fullName: fullName,
        userName: userName,
        ownerType: ownerType,
        phoneNumber: phoneNumber,
        roleId: roleId,
        buildingName: buildingName,
        apartmentNum: apartmentNum,
        compoundId: compoundId,
      );
      roleName = Roles.values[roleId - 1];
      selectedCompoundId = compoundId;
      var compoundLabel = compoundId;
      try {
        if (categoriesBefore.isNotEmpty) {
          compoundLabel = categoriesBefore
              .expand((c) => c.compounds)
              .firstWhere((co) => co.id == compoundId)
              .name;
        }
      } catch (_) {}
      myCompounds = {
        '0': "Add New Community",
        compoundId: compoundLabel,
      };
      await repository.selectCompound(
        compoundId: compoundId,
        compoundName: compoundLabel,
        atWelcome: true,
      );
      signInGoogle = false;
      signupGoogleEmail = null;
      signupGoogleUserName = null;
      emit(RegistrationSuccess());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String displayName,
    required OwnerTypes ownerType,
    required String phoneNumber,
  }) async {
    emit(AuthLoading());
    try {
      await repository.updateProfile(
        fullName: fullName,
        displayName: displayName,
        ownerType: ownerType,
        phoneNumber: phoneNumber,
      );
      emit(ProfileUpdated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> requestEmailChange(String newEmail,
      {String? redirectUrl}) async {
    emit(AuthLoading());
    try {
      await repository.requestEmailChange(newEmail, redirectUrl: redirectUrl);
      emit(EmailChangeRequested());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    emit(AuthLoading());
    try {
      await repository.updatePassword(newPassword);
      emit(PasswordUpdated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  void getSuggestions(TextEditingController controller) {
    final query = controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      compoundSuggestions = [];
    } else {
      compoundSuggestions = state.categories.map((category) {
        // Check if category name matches
        final categoryNameMatches = category.name.toLowerCase().contains(query);

        // Filter compounds that match
        final matchingCompounds = category.compounds.where((compound) {
          return compound.name.toLowerCase().contains(query) ||
              (compound.developer?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (categoryNameMatches) {
          // If category matches, show all its compounds
          return category;
        } else if (matchingCompounds.isNotEmpty) {
          // If only specific compounds match, return category with only those compounds
          return Category(
            id: category.id,
            name: category.name,
            compounds: matchingCompounds,
          );
        }
        return null;
      }).whereType<Category>().toList();
    }
    if (state is Authenticated) {
      emit((state as Authenticated)
          .copyWith(timestamp: DateTime.now().millisecondsSinceEpoch));
    } else {
      emit(AuthInitial(
        categories: state.categories,
        compoundsLogos: state.compoundsLogos,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Future<void> loadCompounds() async {
    if (_loadCompoundsInProgress) {
      if (kDebugMode) {
        debugPrint('[AuthCubit] loadCompounds: skipped (already in progress)');
      }
      return;
    }
    _loadCompoundsInProgress = true;
    if (kDebugMode) {
      debugPrint(
        '[AuthCubit] loadCompounds: start state=${state.runtimeType} '
        'categories=${state.categories.length} logos=${state.compoundsLogos.length}',
      );
    }
    emit(AuthLoading(
        categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      // Load Appwrite category/compound rows and local asset logo paths in parallel
      // (logos are only ever read from the asset manifest — not from Appwrite).
      final results = await Future.wait<Object>([
        repository.loadCompounds(),
        AssetHelper.loadCompoundLogos(),
      ]);
      final fetchedCategories = results[0] as List<Category>;
      final fetchedLogos = results[1] as List<String>;
      if (kDebugMode) {
        final nCompounds = fetchedCategories.fold<int>(
            0, (s, c) => s + c.compounds.length);
        debugPrint(
          '[AuthCubit] loadCompounds: success → ${fetchedCategories.length} category/column(s), '
          '$nCompounds compound(s), ${fetchedLogos.length} asset logo path(s)',
        );
      }

      if (state is Authenticated) {
        emit((state as Authenticated).copyWith(
          categories: fetchedCategories,
          compoundsLogos: fetchedLogos,
        ));
      } else {
        emit(AuthInitial(
          categories: fetchedCategories,
          compoundsLogos: fetchedLogos,
        ));
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AuthCubit] loadCompounds: ERROR $e\n$st');
      }
      emit(AuthError(e.toString(),
          categories: state.categories,
          compoundsLogos: state.compoundsLogos));
    } finally {
      _loadCompoundsInProgress = false;
    }
  }

  Future<void> loadCompoundMembers(String compoundId) async {
    emit(AuthLoading());
    try {
      final Roles? currentRole =
          (state is Authenticated) ? (state as Authenticated).role : null;
      final result = await repository.loadCompoundMembers(compoundId,
          role: currentRole);
      final members = result.members;
      final membersData = result.membersData;

      final currentUserId = (state is Authenticated)
          ? (state as Authenticated).user.id
          : repository.currentUser?.id;
      final currentMember = members.firstWhere(
        (member) => member.id.trim() == currentUserId,
        orElse: () => members.isNotEmpty
            ? members.first
            : throw Exception("User not found in members"),
      );

      if (state is Authenticated) {
        emit((state as Authenticated).copyWith(
          chatMembers: members,
          membersData: membersData,
          currentUser: currentMember,
        ));
      } else {
        emit(CompoundMembersUpdated(
          compoundId: compoundId,
          chatMembers: members,
          membersData: membersData,
          currentUser: currentMember,
        ));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  void updateChatMembers(List<ChatMember> updatedMembers) {
    if (state is Authenticated) {
      final s = state as Authenticated;

      ChatMember? current = s.currentUser;
      final currentUserId = s.user.id;
      final newCurrent = updatedMembers.firstWhere(
        (m) => m.id == currentUserId,
        orElse: () => current ?? updatedMembers.first,
      );

      emit(s.copyWith(chatMembers: updatedMembers, currentUser: newCurrent));
    }
  }

  @override
  Future<void> close() {
    _detachRealtimeUserObservers();
    return super.close();
  }
}
