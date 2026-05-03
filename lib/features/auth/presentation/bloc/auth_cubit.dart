/**
 * [AuthCubit]
 *
 * This file manages the UI state for authentication, registration, and user context.
 */
import 'dart:async';
import 'dart:convert';
import 'package:WhatsUnity/core/config/app_directory_types.dart' show Users;
import 'package:WhatsUnity/core/config/runtime_env.dart';
import 'package:WhatsUnity/core/utils/app_logger.dart';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/appwrite.dart';
import '../../../../core/constants/Constants.dart';
import '../../../../core/models/CompoundsList.dart';
import '../../../../core/network/CacheHelper.dart';
import '../../../chat/data/models/chat_member_model.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Manages the authentication lifecycle and UI state for the Auth feature.
/// 
/// Responsibilities:
/// 1. Initialize sessions and restore local state.
/// 2. Handle sign-in/up/out flows.
/// 3. Observe realtime role changes and profile updates.
/// 4. Manage multi-compound selection and member data.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository repository;

  // ── UI State Fields ──────────────────────────────────────────────────────

  bool isPassword = true;
  IconData suffixIcon = Icons.visibility_off;
  bool signInToggler = true;
  OwnerTypes ownerType = OwnerTypes.owner;
  String? signupGoogleEmail;
  String? signupGoogleUserName;
  bool signInGoogle = false;
  
  /// Unique identifier for the current session. Used as a ValueKey in main.dart
  /// to force a hard-refresh of the app tree for teardown safety and moderation.
  int authSessionNonce = DateTime.now().microsecondsSinceEpoch;

  bool signingIn = false;
  bool googleSigningIn = false;
  bool enabledMultiCompound = false;
  List<XFile>? verFiles;
  final List<double> uploadProgress = [];
  bool apartmentConflict = false;

  List<Category> compoundSuggestions = [];

  Roles? roleName;
  String? selectedCompoundId;
  Map<String, dynamic> myCompounds = {'0': "Add New Community"};

  /// Set of occupied apartment keys (building_apartment) for the currently 
  /// selected/typed compound in the registration flow.
  final Set<String> _occupiedApartments = {};
  RealtimeSubscription? _occupancySubscription;

  // ── Lifecycle & Realtime Fields ──────────────────────────────────────────

  bool _fetchCompoundsInProgress = false;
  Future<void>? _authSessionInitializationInFlight;
  bool _isSigningOut = false;
  RealtimeSubscription? _profilesRealtimeSubscription;
  RealtimeSubscription? _userRolesRealtimeSubscription;
  String? _realtimeObservedUserId;
  bool _refreshFromRealtimeInProgress = false;

  AuthCubit({required this.repository}) : super(AuthInitial()) {
    _setupWebGoogleAuth();
    _listenToAuthState();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Lifecycle & Initialization
  // ─────────────────────────────────────────────────────────────────────────

  /// Restores the auth session from local storage or Appwrite.
  /// This is the primary entry point for the app's auth state bootstrap.
  Future<void> initializeAuthSession() async {
    final inFlight = _authSessionInitializationInFlight;
    if (inFlight != null) return inFlight;

    final future = _initializeAuthSessionImpl();
    _authSessionInitializationInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_authSessionInitializationInFlight, future)) {
        _authSessionInitializationInFlight = null;
      }
    }
  }

  /// Implementation of session initialization. Fetches categories, current user,
  /// role, and compound data from the repository.
  Future<void> _initializeAuthSessionImpl() async {
    AppLogger.d("_initializeAuthSessionImpl starting...",  tag: "AuthCubit");
    // Only emit AuthLoading if we don't have enough state to show the current screen
    if (state is AuthInitial || state is Unauthenticated) {
      emit(AuthLoading(categories: state.categories, compoundsLogos: state.compoundsLogos));
    }
    try {
      final result = await repository.prepareAuthSession().timeout(const Duration(seconds: 25));
      AppLogger.d("prepareAuthSession result: user=${result.user?.id}, role=${result.role}, incomplete=${result.isProfileIncomplete}", tag: "AuthCubit");

      if (result.user == null) {
        emit(Unauthenticated(
          categories: result.categories,
          compoundsLogos: result.compoundsLogos,
        ));
        return;
      }

      // Handle incomplete profile (e.g. Google login without registration details)
      if (result.isProfileIncomplete) {
        // On Web, always go to registration if incomplete (native HTML button)
        // On Android, only go to registration if explicitly in a Google flow
        if (kIsWeb || (signInGoogle)) {
          signupGoogleEmail ??= result.user?.email;
          signupGoogleUserName ??= result.user?.userMetadata?['full_name'] ?? result.user?.userMetadata?['name'];

          signInToggler = false;
          emit(GoogleSignupState(
            categories: state.categories,
            compoundsLogos: state.compoundsLogos,
          ));
          return;
        }
      } else {
        // If the profile is NOT incomplete, ensure we reset the Google-registration flags
        // so the UI doesn't think we are still trying to sign up.
        signInGoogle = false;
        signupGoogleEmail = null;
        signupGoogleUserName = null;
      }

      selectedCompoundId = result.selectedCompoundId;
      myCompounds = result.myCompounds;

      final currentSessionUser = repository.currentUser;
      final role = result.role;

      if (currentSessionUser != null && role != null) {
        AppLogger.d("Authenticated session ready for user: ${currentSessionUser.id}", tag: "AuthCubit");
        _attachRealtimeUserObservers(currentSessionUser.id);
        emit(Authenticated(
          user: currentSessionUser,
          role: role,
          selectedCompoundId: result.selectedCompoundId,
          myCompounds: result.myCompounds,
          chatMembers: result.chatMembers,
          membersData: result.membersData,
          currentUser: result.currentUserMember,
          categories: result.categories,
          compoundsLogos: result.compoundsLogos,
          timestamp: DateTime.now().microsecondsSinceEpoch,
        ));
      } else {
        AppLogger.d("Session data incomplete: user=${currentSessionUser?.id}, role=$role. Emitting Unauthenticated.", tag: "AuthCubit");
        emit(Unauthenticated(
          categories: result.categories,
          compoundsLogos: result.compoundsLogos,
        ));
      }
    } catch (e, st) {
      AppLogger.e("Error in initializeAuthSession", error: e, stackTrace: st, tag: "AuthCubit");
      // Fallback to Unauthenticated if initialization fails, 
      // ensuring we don't get stuck in a loading loop.
      emit(Unauthenticated(
        categories: state.categories, 
        compoundsLogos: state.compoundsLogos
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Core Authentication Actions
  // ─────────────────────────────────────────────────────────────────────────

  /// Standard email/password sign in flow.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    AppLogger.d("signInWithPassword started for $email", tag: "AuthCubit");
    emit(AuthLoading(categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      final user = await repository.signInWithPassword(email: email, password: password);
      if (user != null) {
        AppLogger.d("signInWithPassword successful for ${user.id}", tag: "AuthCubit");
        await repository.saveLocalSession();
        // Force reset UI flags before initializing session
        signInGoogle = false;
        signupGoogleEmail = null;
        signupGoogleUserName = null;
        // _listenToAuthState will handle the navigation by triggering initializeAuthSession
      } else {
        AppLogger.d("signInWithPassword returned null user", tag: "AuthCubit");
        emit(Unauthenticated(categories: state.categories, compoundsLogos: state.compoundsLogos));
      }
    } catch (e) {
      AppLogger.e("signInWithPassword error", error: e, tag: "AuthCubit");
      emit(AuthError(e.toString(), categories: state.categories, compoundsLogos: state.compoundsLogos));
    }
  }

  /// Initiates Google OAuth flow via Appwrite.
  Future<void> signInWithGoogle({bool isSignin = false}) async {
    AppLogger.d("signInWithGoogle started (isSignin: $isSignin)", tag: "AuthCubit");
    emit(AuthLoading(categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      signInGoogle = !isSignin;
      final user = await repository.signInWithGoogle();
      if (user != null) {
        AppLogger.d("signInWithGoogle session established: ${user.id}", tag: "AuthCubit");
        await repository.saveLocalSession();
        // _listenToAuthState will handle the navigation by triggering initializeAuthSession
      } else {
        AppLogger.d("signInWithGoogle cancelled or failed", tag: "AuthCubit");
        signInGoogle = false;
        emit(Unauthenticated(categories: state.categories, compoundsLogos: state.compoundsLogos));
      }
    } catch (e) {
      AppLogger.e("signInWithGoogle error", error: e, tag: "AuthCubit");
      signInGoogle = false;
      emit(AuthError(e.toString(), categories: state.categories, compoundsLogos: state.compoundsLogos));
    } finally {
      googleSigningIn = false;
    }
  }

  /// Standard email/password sign up flow.
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    emit(AuthLoading());
    try {
      await repository.signUp(email: email, password: password, data: data);
      await repository.saveLocalSession();
      emit(SignUpSuccess(email: email));
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        // User already exists.
        emit(AuthError("User with this email already exists. Please sign in.", categories: state.categories, compoundsLogos: state.compoundsLogos));
        // We can also just emit Unauthenticated to stay on the screen or handle it in UI
      } else {
        emit(AuthError(e.toString()));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Signs out the current user and clears local/remote sessions.
  Future<void> signOut() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    emit(AuthLoading(categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      await _cacheUserSnapshotOnSignOut(); // Backup for offline access
      await repository.signOut();
      // Unauthenticated state is emitted by _listenToAuthState listener when repository notifies null.
    } catch (e) {
      emit(AuthError(e.toString(), categories: state.categories, compoundsLogos: state.compoundsLogos));
    } finally {
      _isSigningOut = false;
    }
  }

  /// Finalizes user registration (profile, role, compound selection) after initial auth.
  Future<void> submitRegistration({
    required String fullName,
    required String userName,
    required OwnerTypes ownerType,
    required String phoneNumber,
    required dynamic roleId,
    required String buildingName,
    required String apartmentNum,
    required String compoundId,
  }) async {
    emit(AuthLoading());
    try {
      // Normalize roleId
      final roleIdString = roleId is Roles ? roleId.name : roleId.toString();

      final result = await repository.processRegistration(
        fullName: fullName,
        userName: userName,
        ownerType: ownerType,
        phoneNumber: phoneNumber,
        roleId: roleIdString,
        buildingName: buildingName,
        apartmentNum: apartmentNum,
        compoundId: compoundId,
      );

      roleName = result.role;
      selectedCompoundId = result.selectedCompoundId;
      myCompounds = result.myCompounds;

      signInGoogle = false;
      signupGoogleEmail = null;
      signupGoogleUserName = null;
      
      await repository.saveLocalSession();
      
      // Emit Authenticated immediately to trigger navigation
      final user = repository.currentUser;
      if (user != null) {
        emit(Authenticated(
          user: user,
          role: result.role,
          selectedCompoundId: compoundId,
          myCompounds: myCompounds,
          categories: state.categories,
          compoundsLogos: state.compoundsLogos,
          timestamp: DateTime.now().microsecondsSinceEpoch,
        ));
      }
      
      emit(RegistrationSuccess(
        categories: state.categories,
        compoundsLogos: state.compoundsLogos,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Cancels a pending Google registration and signs the user out.
  Future<void> cancelPendingGoogleRegistration() async {
    emit(AuthLoading(categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      await repository.signOut();
      // Reset all registration-related UI flags
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
      emit(AuthError(e.toString(), categories: state.categories, compoundsLogos: state.compoundsLogos));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Profile & Account Management
  // ─────────────────────────────────────────────────────────────────────────

  /// Updates profile metadata in the Appwrite 'profiles' collection.
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
      await repository.saveLocalSession();
      emit(ProfileUpdated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Requests an email change (Backend requires password verification).
  Future<void> requestEmailChange(String newEmail, {String? redirectUrl}) async {
    emit(AuthLoading());
    try {
      await repository.requestEmailChange(newEmail, redirectUrl: redirectUrl);
      emit(EmailChangeRequested());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Updates the current user's password.
  Future<void> updatePassword(String newPassword) async {
    emit(AuthLoading());
    try {
      await repository.updatePassword(newPassword);
      emit(PasswordUpdated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Uploads residency verification documents (KYC).
  Future<void> submitVerificationFiles() async {
    if (verFiles == null || verFiles!.isEmpty) return;
    emit(AuthLoading());
    try {
      final userId = (state is Authenticated) ? (state as Authenticated).user.id : repository.currentUser?.id;
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
          _refreshUI();
        },
      );
      _refreshUI();
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Compound & Member Actions
  // ─────────────────────────────────────────────────────────────────────────

  /// Switches the active compound for the current session.
  Future<void> selectCompound({
    required String compoundId,
    required String compoundName,
    required bool atWelcome,
  }) async {
    try {
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
      
      await repository.saveLocalSession();

      if (state is Authenticated) {
        emit((state as Authenticated).copyWith(
          selectedCompoundId: compoundId,
          myCompounds: Map<String, dynamic>.from(myCompounds),
        ));
      } else {
        emit(CompoundSelected(compoundId));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Fetches global list of available compounds and categories.
  Future<void> fetchCompounds() async {
    if (_fetchCompoundsInProgress) return;
    _fetchCompoundsInProgress = true;
    
    emit(AuthLoading(categories: state.categories, compoundsLogos: state.compoundsLogos));
    try {
      final results = await Future.wait<Object>([
        repository.loadCompounds(),
        AssetHelper.loadCompoundLogos(),
      ]);
      final fetchedCategories = results[0] as List<Category>;
      final fetchedLogos = results[1] as List<String>;

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
    } catch (e) {
      emit(AuthError(e.toString(), categories: state.categories, compoundsLogos: state.compoundsLogos));
    } finally {
      _fetchCompoundsInProgress = false;
    }
  }

  /// Loads member list for a specific compound (restricted by user role).
  Future<void> fetchCompoundMembers(String compoundId) async {
    emit(AuthLoading());
    try {
      final Roles? currentRole = (state is Authenticated) ? (state as Authenticated).role : null;
      final result = await repository.loadCompoundMembers(compoundId, role: currentRole);
      final members = result.members;
      final membersData = result.membersData;

      final currentUserId = (state is Authenticated) ? (state as Authenticated).user.id : repository.currentUser?.id;
      final currentMember = members.firstWhere(
        (member) => member.id.trim() == currentUserId,
        orElse: () => members.isNotEmpty ? members.first : throw Exception("User not found in members"),
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

  /// Updates the chat members list in the state (UI helper).
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

  /// Verifies if a specific apartment unit is already registered.
  Future<void> isApartmentTaken({
    required String compoundId,
    required String buildingName,
    required String apartmentNum,
  }) async {
    // 1. Initial check (transient)
    final key = '${buildingName}_$apartmentNum';
    if (_occupiedApartments.contains(key)) {
      apartmentConflict = true;
      emit(ApartmentTakenStatus(isTaken: true));
      return;
    }

    try {
      final taken = await repository.isApartmentTaken(
        compoundId: compoundId,
        buildingName: buildingName,
        apartmentNum: apartmentNum,
      );
      apartmentConflict = taken;
      if (taken) _occupiedApartments.add(key);
      emit(ApartmentTakenStatus(isTaken: taken));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Checks if an apartment is already known to be occupied (realtime/cached).
  bool isApartmentOccupied(String buildingName, String apartmentNum) {
    return _occupiedApartments.contains('${buildingName}_$apartmentNum') || apartmentConflict;
  }

  /// Subscribes to realtime updates for a specific compound's occupancy and new members.
  void subscribeToCompoundEvents(String compoundId) {
    _occupancySubscription?.close();
    
    // Subscribe to user_apartments for this compound
    _occupancySubscription = appwriteRealtime.subscribe([
      'databases.$appwriteDatabaseId.collections.user_apartments.documents'
    ]);

    _occupancySubscription!.stream.listen((event) {
      final data = event.payload;
      // Filter by compoundId
      if (data['compound_id'] != compoundId) return;

      final b = data['building_name']?.toString() ?? '';
      final a = data['apartment_num']?.toString() ?? '';
      final key = '${b}_$a';

      if (event.events.contains('*.create')) {
        _occupiedApartments.add(key);
        
        // DETECTION OF NEWCOMERS:
        // When a new apartment is registered, trigger a member sync
        // and update the chat list.
        _handleNewcomer(compoundId);
      } else if (event.events.contains('*.delete')) {
        _occupiedApartments.remove(key);
      }
      
      _refreshUI();
    });
  }

  Future<void> _handleNewcomer(String compoundId) async {
    // Re-load members (delta-sync logic in repo handles the efficiency)
    final result = await repository.loadCompoundMembers(compoundId);
    
    // Update state with new member list if already authenticated
    if (state is Authenticated) {
      final s = state as Authenticated;
      emit(s.copyWith(
        chatMembers: result.members,
        membersData: result.membersData,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. UI Helpers & Form Handlers
  // ─────────────────────────────────────────────────────────────────────────

  /// Toggles visibility of the password field.
  void togglePasswordVisibility() {
    isPassword = !isPassword;
    suffixIcon = isPassword ? Icons.visibility_off : Icons.visibility;
    // DO NOT EMIT STATE HERE - just let the UI widgets use the local variable
    // or use a dedicated local UI state if needed. 
    // Emitting state here triggers app-wide refreshes if listeners are too broad.
    _refreshUI();
  }

  /// Switches between Sign In and Sign Up views.
  void toggleSignIn() {
    signInToggler = !signInToggler;
    _refreshUI();
  }

  /// Toggles the loading flag for standard sign-in.
  void signInSwitcher() {
    signingIn = !signingIn;
    _refreshUI();
  }

  /// Toggles the loading flag for Google sign-in.
  void googleSignInSwitcher() {
    googleSigningIn = !googleSigningIn;
    _refreshUI();
  }

  /// Updates the active role selection in the registration form.
  void changeRole(Roles? newRole) {
    roleName = newRole ?? Roles.user;
    _refreshUI();
  }

  /// Updates the owner/tenant selection.
  void changeOwnerType(OwnerTypes newType) {
    ownerType = newType;
    _refreshUI();
  }

  /// Filters compound suggestions based on search query.
  void fetchSuggestions(TextEditingController controller) {
    final query = controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      compoundSuggestions = [];
    } else {
      compoundSuggestions = state.categories.map((category) {
        final categoryNameMatches = category.name.toLowerCase().contains(query);
        final matchingCompounds = category.compounds.where((compound) {
          return compound.name.toLowerCase().contains(query) ||
              (compound.developer?.toLowerCase().contains(query) ?? false);
        }).toList();

        if (categoryNameMatches) return category;
        if (matchingCompounds.isNotEmpty) {
          return Category(id: category.id, name: category.name, compounds: matchingCompounds);
        }
        return null;
      }).whereType<Category>().toList();
    }
    _refreshUI();
  }

  /// Opens image picker for verification documents.
  Future<void> verFileImport() async {
    final List<XFile> result = await ImagePicker().pickMultiImage(imageQuality: 70, maxWidth: 1440);
    if (result.isEmpty) return;
    verFiles = result;
    _refreshUI();
  }

  /// Clears selected verification files.
  void clearVerFiles() {
    verFiles = null;
    _refreshUI();
  }

  /// Resets the auth state to AuthInitial.
  Future<void> resetUserData() async {
    emit(AuthInitial(categories: state.categories, compoundsLogos: state.compoundsLogos));
  }

  /// Manually updates the local role in the state (UI helper).
  void updateRole(Roles role) {
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith(role: role));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Realtime & Internal Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Listens to authoritative auth state changes from the repository.
  void _listenToAuthState() {
    repository.onAuthStateChange.listen((appUser) {
      if (appUser == null) {
        AppLogger.d("User is null in stream, clearing session", tag: "AuthCubit");
        _detachRealtimeUserObservers();
        // Reset nonce on logout
        authSessionNonce = DateTime.now().microsecondsSinceEpoch;
        signInToggler = true;
        emit(Unauthenticated(categories: state.categories, compoundsLogos: state.compoundsLogos));
        return;
      }

      AppLogger.d("_listenToAuthState received: ${appUser.id}", tag: "AuthCubit");
      try {
        final currentAuth = state is Authenticated ? (state as Authenticated) : null;
        
        // Nonce management: only trigger app-wide refresh if a new user logged in.
        if (currentAuth == null || currentAuth.user.id != appUser.id) {
           AppLogger.d("New user or session detected via stream", tag: "AuthCubit");
           // Only update nonce on ACTUAL login/logout to stabilize UI
           authSessionNonce = DateTime.now().microsecondsSinceEpoch;
           
           // If we are already initializing (e.g. at startup), don't trigger a second one
           if (_authSessionInitializationInFlight == null) {
              AppLogger.d("Triggering initialization from stream", tag: "AuthCubit");
              unawaited(initializeAuthSession());
           } else {
              AppLogger.d("Initialization already in flight, skipping stream trigger", tag: "AuthCubit");
           }
        } else {
          AppLogger.d("Existing user updated via stream", tag: "AuthCubit");
          _attachRealtimeUserObservers(appUser.id);
          emit(currentAuth.copyWith(user: appUser));
          unawaited(repository.saveLocalSession());
        }
      } catch (e) {
        AppLogger.e("auth stream handler error", error: e, tag: "AuthCubit");
      }
    });
  }

  /// Subscribes to Appwrite Realtime for profile and role updates.
  void _attachRealtimeUserObservers(String userId) {
    if (_realtimeObservedUserId == userId) return;
    _detachRealtimeUserObservers();
    _realtimeObservedUserId = userId;

    const String colProfiles = 'profiles';
    const String colUserRoles = 'user_roles';

    try {
      // 1. Profile updates (display name, user_state, etc.)
      final profileChannels = [
        'databases.$appwriteDatabaseId.collections.$colProfiles.documents',
        'databases.$appwriteDatabaseId.tables.$colProfiles.rows',
      ];
      _profilesRealtimeSubscription = appwriteRealtime.subscribe(profileChannels);
      _profilesRealtimeSubscription!.stream.listen((message) {
        final payload = Map<String, dynamic>.from(message.payload);
        final eventId = (payload[r'$id'] ?? payload['id'] ?? '').toString();
        if (eventId.isEmpty) return;

        if (eventId == userId) {
          AppLogger.d("Realtime profile update received for CURRENT user", tag: "AuthCubit");
          unawaited(_refreshAuthenticatedStateFromRemote());
        } else {
          AppLogger.d("Realtime profile update received for user $eventId", tag: "AuthCubit");
          _handleOtherProfileUpdate(eventId, payload);
        }
      });

      // 2. Role changes
      final userRoleChannels = [
        'databases.$appwriteDatabaseId.collections.$colUserRoles.documents',
        'databases.$appwriteDatabaseId.tables.$colUserRoles.rows',
      ];
      _userRolesRealtimeSubscription = appwriteRealtime.subscribe(userRoleChannels);
      _userRolesRealtimeSubscription!.stream.listen((message) {
        final payload = Map<String, dynamic>.from(message.payload);
        final eventUserId = (payload['user_id'] ?? payload[r'$id'] ?? '').toString().trim();
        if (eventUserId.isEmpty) return;

        final roleFromPayload = _resolveRoleFromRoleId(payload['role_id']);

        if (eventUserId == userId) {
          AppLogger.d("Realtime role update received for CURRENT user", tag: "AuthCubit");
          if (roleFromPayload != null && state is Authenticated) {
            emit((state as Authenticated).copyWith(
              role: roleFromPayload,
              timestamp: DateTime.now().microsecondsSinceEpoch,
            ));
            unawaited(repository.saveLocalSession());
          }
          unawaited(_refreshAuthenticatedStateFromRemote());
        } else {
          AppLogger.d("Realtime role update received for user $eventUserId", tag: "AuthCubit");
          _handleOtherUserRoleUpdate(eventUserId, roleFromPayload);
        }
      });
    } catch (e) {
      AppLogger.e("Realtime setup failed", error: e, tag: "AuthCubit");
    }
  }

  /// Updates the state when another user's profile changes.
  void _handleOtherProfileUpdate(String eventId, Map<String, dynamic> payload) {
    if (state is! Authenticated) return;
    final current = state as Authenticated;

    final updatedMembers = current.chatMembers.map((m) {
      if (m.id == eventId) {
        return m.copyWithProfileUpdate(payload);
      }
      return m;
    }).toList();

    // Also update membersData if the user is present there
    final updatedMembersData = current.membersData.map((u) {
      if (u.authorId == eventId) {
        return Users(
          authorId: u.authorId,
          phoneNumber: (payload['phone_number'] ?? payload['phoneNumber'] ?? u.phoneNumber).toString(),
          updatedAt: DateTime.tryParse((payload[r'$updatedAt'] ?? payload['updated_at'] ?? '').toString()) ?? u.updatedAt,
          ownerShipType: (payload['owner_type'] ?? payload['ownerShipType'] ?? u.ownerShipType).toString(),
          userState: (payload['userState'] ?? payload['user_state'] ?? u.userState).toString(),
          actionTakenBy: u.actionTakenBy,
          verFile: u.verFile,
        );
      }
      return u;
    }).toList();

    emit(current.copyWith(
      chatMembers: updatedMembers,
      membersData: updatedMembersData,
      timestamp: DateTime.now().microsecondsSinceEpoch,
    ));
  }

  /// Updates the state when another user's role changes.
  void _handleOtherUserRoleUpdate(String eventUserId, Roles? newRole) {
    if (state is! Authenticated || newRole == null) return;
    final current = state as Authenticated;

    // In this app, roles are often handled separately from chatMembers profile data,
    // but some UI elements might depend on the membersData list for admin views.
    final updatedMembersData = current.membersData.map((u) {
      if (u.authorId == eventUserId) {
        // If Users entity had a role field, we would update it here.
        // For now, we trigger a timestamp refresh to notify listeners.
      }
      return u;
    }).toList();

    emit(current.copyWith(
      membersData: updatedMembersData,
      timestamp: DateTime.now().microsecondsSinceEpoch,
    ));
  }

  /// Forces a fresh pull of the current user profile from Appwrite.
  Future<void> _refreshAuthenticatedStateFromRemote() async {
    if (_refreshFromRealtimeInProgress) return;
    _refreshFromRealtimeInProgress = true;
    try {
      final refreshedUser = await repository.fetchCurrentUser();
      if (refreshedUser == null) return;
      
      // Trigger a full re-initialization to update all fields (role, userState in membersData, etc.)
      // and notify all listeners (like MainScreen) with the new timestamp.
      unawaited(initializeAuthSession());

      await repository.saveLocalSession();
    } finally {
      _refreshFromRealtimeInProgress = false;
    }
  }

  /// Closes all active realtime subscriptions.
  void _detachRealtimeUserObservers() {
    _profilesRealtimeSubscription?.close();
    _profilesRealtimeSubscription = null;
    _userRolesRealtimeSubscription?.close();
    _userRolesRealtimeSubscription = null;
    _realtimeObservedUserId = null;
  }

  /// Configures Google SDK for Web environments.
  void _setupWebGoogleAuth() {
    if (!kIsWeb) return;
    GoogleSignIn.instance.initialize(clientId: RuntimeEnv.googleServerClientId);
    GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final auth = event.user.authentication;
        if (auth.idToken != null) await repository.signInWithGoogleWeb(auth.idToken!);
      }
    });
    // DISABLED: prevent persistent popup on every refresh/boot.
    // GoogleSignIn.instance.attemptLightweightAuthentication()?.catchError((_) => null);
  }

  /// Triggers a state rebuild with existing data to refresh UI listeners.
  void _refreshUI() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (state is Authenticated) {
      emit((state as Authenticated).copyWith(timestamp: now));
    } else if (state is Unauthenticated) {
      emit(Unauthenticated(categories: state.categories, compoundsLogos: state.compoundsLogos, timestamp: now));
    } else if (state is GoogleSignupState) {
      emit(GoogleSignupState(categories: state.categories, compoundsLogos: state.compoundsLogos, timestamp: now));
    } else if (state is ApartmentTakenStatus) {
      emit(ApartmentTakenStatus(isTaken: (state as ApartmentTakenStatus).isTaken, categories: state.categories, compoundsLogos: state.compoundsLogos, timestamp: now));
    } else if (state is CompoundSelected) {
      emit(CompoundSelected((state as CompoundSelected).compoundId, categories: state.categories, compoundsLogos: state.compoundsLogos, timestamp: now));
    } else if (state is RegistrationSuccess) {
      emit(RegistrationSuccess(categories: state.categories, compoundsLogos: state.compoundsLogos, timestamp: now));
    } else {
      emit(AuthInitial(categories: state.categories, compoundsLogos: state.compoundsLogos, timestamp: now));
    }
  }

  /// Helper to map string role IDs to Roles enum.
  Roles? _resolveRoleFromRoleId(dynamic roleRaw) {
    if (roleRaw == null) return null;
    final str = (roleRaw is String) ? roleRaw : roleRaw.toString();
    final t = str.trim();
    if (t.isEmpty) return null;
    final byName = Roles.values.where((r) => r.name == t).toList();
    return byName.isNotEmpty ? byName.first : null;
  }

  /// Caches a lightweight snapshot of the user before sign-out.
  Future<void> _cacheUserSnapshotOnSignOut() async {
    if (state is! Authenticated) return;
    final user = (state as Authenticated).user;
    final payload = {
      'email': user.email ?? '',
      'selectedCompoundId': (state as Authenticated).selectedCompoundId,
      'myCompounds': (state as Authenticated).myCompounds,
      'role_id': user.userMetadata?['role_id'],
    };
    await CacheHelper.saveData(key: CacheHelper.cachedUserDataKey(user.id), value: jsonEncode(payload));
  }

  @override
  Future<void> close() {
    _detachRealtimeUserObservers();
    return super.close();
  }
}
