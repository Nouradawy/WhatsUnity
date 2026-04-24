import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// ── Supabase is kept initialised for Phase-2 compatibility ──────────────────
// Non-auth features (Chat, Social, Maintenance, Presence) still talk directly
// to Supabase until their own migration phases complete. Remove once every data
// source is on Appwrite.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/services/database_helper.dart';
import 'core/utils/BlocObserver.dart';
import 'core/constants/Constants.dart';
import 'core/config/Enums.dart';
import 'core/config/supabase.dart';
import 'core/config/appwrite.dart';
import 'core/theme/lightTheme.dart';

import 'features/auth/domain/entities/app_user.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/chat/data/datasources/chat_local_data_source.dart';
import 'features/chat/data/datasources/chat_remote_data_source.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/presentation/bloc/presence_cubit.dart';
import 'features/maintenance/data/datasources/maintenance_remote_data_source.dart';
import 'features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'features/maintenance/presentation/bloc/maintenance_cubit.dart';
import 'features/maintenance/presentation/bloc/manager_cubit.dart';
import 'features/social/data/datasources/social_remote_data_source.dart';
import 'features/social/data/repositories/social_repository_impl.dart';
import 'features/social/presentation/bloc/social_cubit.dart';
import 'features/profile/presentation/bloc/profile_cubit.dart';
import 'features/chat/presentation/bloc/chat_details_cubit.dart';
import 'features/chat/presentation/bloc/message_receipts_cubit.dart';
import 'core/services/GoogleDriveService.dart';

import 'Layout/Cubit/cubit.dart';
import 'features/admin/presentation/bloc/report_cubit.dart';

import 'features/admin/data/datasources/admin_remote_data_source.dart';
import 'features/admin/data/repositories/admin_repository_impl.dart';
import 'features/admin/presentation/bloc/admin_cubit.dart';
import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/data/auth_ready_gate.dart';

import 'features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = const SimpleBlocObserver();
  await dotenv.load(fileName: ".env");

  // ── Appwrite (auth primary backend) ───────────────────────────────────────
  await initAppwrite();

  // ── Supabase (kept for non-auth features until full migration) ────────────
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  supabase = Supabase.instance.client;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ChatLocalDataSource>(
      create: (_) => ChatLocalDataSourceImpl(DatabaseHelper.instance),
      child: RepositoryProvider<ChatRepository>(
        create: (context) => ChatRepositoryImpl(
          remoteDataSource: ChatRemoteDataSourceImpl(
            databases: appwriteDatabases,
            realtime: appwriteRealtime,
          ),
          localDataSource: context.read<ChatLocalDataSource>(),
          supabase: supabase,
        ),
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) {
                final authCubit = AuthCubit(
                  repository: AuthRepositoryImpl(
                    remoteDataSource: AppwriteAuthRemoteDataSourceImpl(
                      account: appwriteAccount,
                      oauthSuccessUrl:
                          dotenv.env['APPWRITE_OAUTH_SUCCESS'],
                      oauthFailureUrl:
                          dotenv.env['APPWRITE_OAUTH_FAILURE'],
                    ),
                    supabaseClient: supabase,
                    googleDriveService: driveService,
                    appwriteAccount: appwriteAccount,
                    appwriteTables: appwriteTables,
                  ),
                );
                // Preserved teardown-safe bootstrap — see MIGRATION_PLAN.md §2.3.
                authCubit.presetBeforeSignin();
                return authCubit;
              },
            ),
            BlocProvider(create: (context) => AppCubit()),
            BlocProvider(create: (context) => ReportCubit()),
            BlocProvider(create: (context) => PresenceCubit()),
            BlocProvider(
              create: (context) => AdminCubit(
                adminRepository: AdminRepositoryImpl(
                  remoteDataSource: AppwriteAdminRemoteDataSourceImpl(
                    databases: appwriteDatabases,
                  ),
                ),
              ),
            ),
            BlocProvider(create: (context) => ManagerCubit()),
            BlocProvider(
              create: (context) => ChatDetailsCubit(
                authCubit: context.read<AuthCubit>(),
              ),
            ),
            BlocProvider(
              create: (context) {
                final authState = context.read<AuthCubit>().state;
                final members = (authState is Authenticated)
                    ? authState.chatMembers
                    : <ChatMember>[];
                return MessageReceiptsCubit(supabase, chatMembers: members);
              },
            ),
            BlocProvider(
              create: (context) => MaintenanceCubit(
                repository: MaintenanceRepositoryImpl(
                  remoteDataSource: AppwriteMaintenanceRemoteDataSourceImpl(
                    databases: appwriteDatabases,
                  ),
                  driveService: GoogleDriveService(),
                  supabaseClient: supabase,
                ),
              ),
            ),
            BlocProvider(
              create: (context) => SocialCubit(
                repository: SocialRepositoryImpl(
                  remoteDataSource: SocialRemoteDataSourceImpl(
                    databases: appwriteDatabases,
                  ),
                  driveService: GoogleDriveService(),
                ),
              ),
            ),
            BlocProvider(create: (context) => ProfileCubit()),
          ],
          child: ChangeNotifierProvider(
            create: (context) => AuthManager(
              // AuthRepositoryImpl is the same instance held by AuthCubit.
              authRepository: context.read<AuthCubit>().repository,
            ),
            child: MaterialApp(
              title: 'WhatsUnity',
              debugShowCheckedModeBanner: false,
              theme: myLightTheme(),
              supportedLocales: L10n.all,
              localeResolutionCallback: (deviceLocale, supportedLocales) {
                if (deviceLocale != null &&
                    supportedLocales.any(
                        (l) => l.languageCode == deviceLocale.languageCode)) {
                  return deviceLocale;
                }
                return supportedLocales.first;
              },
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: mq.textScaler
                        .clamp(minScaleFactor: 0.8, maxScaleFactor: 1.0),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              home: BlocBuilder<AuthCubit, AuthState>(
                buildWhen: (previous, current) =>
                    previous.runtimeType != current.runtimeType,
                builder: (context, state) {
                  final authManager = context.watch<AuthManager>();
                  final authCubit = context.read<AuthCubit>();

                  if (authManager.status == AuthStatus.unknown) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (authManager.status == AuthStatus.authenticated &&
                      authCubit.signupGoogleEmail == null &&
                      authCubit.signInGoogle == false) {
                    // ValueKey(authSessionNonce) guarantees a fresh widget
                    // subtree on every new login session — preserves teardown
                    // safety for MainScreen / GeneralChat / Social.
                    return AuthReadyGate(
                      key: ValueKey(authCubit.authSessionNonce),
                    );
                  }

                  return SignUp();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Observes [AuthRepository.onAuthStateChange] (an [AppUser?] stream backed
/// by Appwrite) and updates [status] so the widget tree can react.
///
/// Replaces the old Supabase [StreamSubscription<supabase_auth.AuthState>].
class AuthManager extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  StreamSubscription<AppUser?>? _sub;

  AuthManager({required AuthRepository authRepository}) {
    // Seed synchronously if the repository already has a cached user from
    // its constructor-time _checkExistingSession call.
    final cached = authRepository.currentUser;
    if (cached != null) {
      status = AuthStatus.authenticated;
    }
    // Regardless of sync seed, subscribe so subsequent sign-in / sign-out
    // events (including the async resolution of _checkExistingSession) are
    // reflected without a hot-restart.
    _sub = authRepository.onAuthStateChange.listen((appUser) {
      final next = appUser != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      if (status != next) {
        status = next;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
