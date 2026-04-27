import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/utils/BlocObserver.dart';
import 'core/config/appwrite.dart';
import 'core/media/media_services.dart';
import 'core/theme/lightTheme.dart';
import 'core/di/app_services.dart';

import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/chat/presentation/bloc/presence_cubit.dart';
import 'features/maintenance/data/repositories/maintenance_repository_impl.dart';
import 'features/maintenance/presentation/bloc/maintenance_cubit.dart';
import 'features/maintenance/presentation/bloc/manager_cubit.dart';
import 'features/social/data/datasources/social_remote_data_source.dart';
import 'features/social/data/repositories/social_repository_impl.dart';
import 'features/social/presentation/bloc/social_cubit.dart';
import 'features/profile/presentation/bloc/profile_cubit.dart';
import 'features/chat/presentation/bloc/chat_details_cubit.dart';
import 'features/chat/presentation/bloc/message_receipts_cubit.dart';

import 'Layout/Cubit/cubit.dart';
import 'features/admin/presentation/bloc/report_cubit.dart';
import 'features/admin/presentation/bloc/admin_cubit.dart';

import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/data/auth_ready_gate.dart';
import 'features/ui_ux_prototypes/presentation/pages/uiux_prototype_catalog_page.dart';

import 'features/chat/data/models/chat_member_model.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScreenUtil.ensureScreenSize();
  Bloc.observer = const SimpleBlocObserver();
  await dotenv.load(fileName: ".env");

  // ── Appwrite (auth primary backend) ───────────────────────────────────────
  await initAppwrite();
  initMediaUploadService();
  AppServices.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
                          providers: [
                            BlocProvider(
                              create: (context) {
                                final authCubit = AuthCubit(
                                  repository: AuthRepositoryImpl(
                                    remoteDataSource:
                                        AppwriteAuthRemoteDataSourceImpl(
                                          account: appwriteAccount,
                                        functions: appwriteFunctions,
                                        googleServerClientId:
                                            dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
                                        nativeGoogleBridgeFunctionId:
                                            dotenv
                                                .env['APPWRITE_FUNCTION_GOOGLE_NATIVE_SIGNIN_BRIDGE'],
                                          oauthSuccessUrl:
                                              dotenv
                                                  .env['APPWRITE_OAUTH_SUCCESS'],
                                          oauthFailureUrl:
                                              dotenv
                                                  .env['APPWRITE_OAUTH_FAILURE'],
                                        ),
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
                            BlocProvider(
                              create:
                                  (context) => ReportCubit(
                                    adminRepository:
                                        AppServices.adminRepository,
                                  ),
                            ),
                            BlocProvider(
                              create:
                                  (context) => AdminCubit(
                                    adminRepository:
                                        AppServices.adminRepository,
                                  ),
                            ),
                            BlocProvider(create: (context) => PresenceCubit()),
                            BlocProvider(create: (context) => ManagerCubit()),
                            BlocProvider(
                              create:
                                  (context) => ChatDetailsCubit(
                                    authCubit: context.read<AuthCubit>(),
                                    databases: appwriteTables,
                                  ),
                            ),
                            BlocProvider(
                              create: (context) {
                                final authState =
                                    context.read<AuthCubit>().state;
                                final members =
                                    (authState is Authenticated)
                                        ? authState.chatMembers
                                        : <ChatMember>[];
                                return MessageReceiptsCubit(
                                  AppServices.chatRemoteDataSource,
                                  chatMembers: members,
                                );
                              },
                            ),
                            BlocProvider(
                              create:
                                  (context) => MaintenanceCubit(
                                    repository: MaintenanceRepositoryImpl(
                                      remoteDataSource: AppServices
                                          .maintenanceRemoteDataSource,
                                      localDataSource:
                                          AppServices.maintenanceLocalDataSource,
                                      syncRepository:
                                          AppServices.maintenanceSyncRepository,
                                    ),
                                  ),
                            ),
                            BlocProvider(
                              create:
                                  (context) => SocialCubit(
                                    repository: SocialRepositoryImpl(
                                      remoteDataSource:
                                          SocialRemoteDataSourceImpl(
                                            databases: appwriteTables,
                                          ),
                                    ),
                                  ),
                            ),
                            BlocProvider(create: (context) => ProfileCubit()),
                          ],
                          child: ScreenUtilInit(
                              designSize: const Size(360, 690),
                              minTextAdapt: true,
                              splitScreenMode: true,
                              builder: (context, child) {
                                final prototypeRoutes = kDebugMode
                                    ? {
                                        '/uiux-prototypes': (_) =>
                                            const UiUxPrototypeCatalogPage(),
                                      }
                                    : <String, WidgetBuilder>{};
                                return MaterialApp(
                                  title: 'WhatsUnity',
                                  debugShowCheckedModeBanner: false,
                                  theme: myLightTheme(),
                                  routes: prototypeRoutes,
                                  supportedLocales: L10n.all,
                                  localeResolutionCallback: (
                                    deviceLocale,
                                    supportedLocales,
                                  ) {
                                    if (deviceLocale != null &&
                                        supportedLocales.any(
                                          (l) =>
                                              l.languageCode ==
                                              deviceLocale.languageCode,
                                        )) {
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
                                    ScreenUtil.init(
                                      context,
                                      designSize: const Size(360, 690),
                                      minTextAdapt: true,
                                      splitScreenMode: true,
                                    );
                                    if (child == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final mq = MediaQuery.of(context);
                                    return MediaQuery(
                                      data: mq.copyWith(
                                        textScaler: mq.textScaler.clamp(
                                          minScaleFactor: 0.8,
                                          maxScaleFactor: 1.3,
                                        ),
                                      ),
                                      child: child,
                                    );
                                  },
                                  home: BlocBuilder<AuthCubit, AuthState>(
                                    buildWhen:
                                        (previous, current) =>
                                            previous.runtimeType !=
                                            current.runtimeType,
                                    builder: (context, state) {
                                      final authCubit =
                                          context.read<AuthCubit>();
                                      final authRepository = authCubit.repository;
                                      return StreamBuilder(
                                        stream: authRepository.onAuthStateChange,
                                        initialData: authRepository.currentUser,
                                        builder: (context, snapshot) {
                                          final hasResolvedAuthState =
                                              snapshot.connectionState !=
                                                  ConnectionState.waiting ||
                                              snapshot.data != null;
                                          if (!hasResolvedAuthState) {
                                            return const Scaffold(
                                              body: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          final isAuthenticated =
                                              snapshot.data != null;
                                          if (isAuthenticated &&
                                              authCubit.signupGoogleEmail ==
                                                  null &&
                                              authCubit.signInGoogle == false) {
                                            // ValueKey(authSessionNonce) guarantees a fresh widget
                                            // subtree on every new login session — preserves teardown
                                            // safety for MainScreen / GeneralChat / Social.
                                            return AuthReadyGate(
                                              key: ValueKey(
                                                authCubit.authSessionNonce,
                                              ),
                                            );
                                          }

                                          return SignUp();
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
    );
  }
}

