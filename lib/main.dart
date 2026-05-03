import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/utils/app_logger.dart';
import 'core/services/database_helper.dart';
import 'core/utils/BlocObserver.dart';
import 'core/config/runtime_env.dart';
import 'core/config/appwrite.dart';
import 'core/media/media_services.dart';
import 'core/theme/lightTheme.dart';
import 'core/di/app_services.dart';

import 'features/auth/data/datasources/auth_local_data_source.dart';
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
import 'features/chat/presentation/bloc/mention_notification_cubit.dart';

import 'Layout/Cubit/cubit.dart';
import 'features/admin/presentation/bloc/report_cubit.dart';
import 'features/admin/presentation/bloc/admin_cubit.dart';

import 'features/auth/presentation/pages/signup_page.dart';
import 'features/auth/presentation/pages/signin_page.dart';
import 'features/auth/data/auth_ready_gate.dart';
import 'features/ui_ux_prototypes/presentation/pages/uiux_prototype_catalog_page.dart';

import 'features/chat/data/models/chat_member_model.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';

/// Top-level background message handler for FCM.
/// Required for Android notifications when the app is in terminated state.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background processing if needed.
  // This must be minimal to avoid blocking the OS notification delivery.
  await Firebase.initializeApp();
  AppLogger.d("Handling a background message: ${message.messageId}", tag: 'Main');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.d("Starting WhatsUnity initialization...", tag: 'Main');

  // ── Firebase (native push) ────────────────────────────────────────────────
  // Initialized early in main() to ensure background handlers are registered
  // before the UI tree starts.
  if (!kIsWeb) {
    try {
      AppLogger.d("Initializing Firebase...", tag: 'Main');
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      AppLogger.d("Firebase initialized.", tag: 'Main');
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      AppLogger.d("FCM background handler registered.", tag: 'Main');
    } catch (e) {
      AppLogger.e("Firebase early initialization failed or timed out", tag: 'Main', error: e);
    }
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.e(details.exceptionAsString(), tag: 'Main');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.e("Uncaught async error", tag: 'Main', error: error, stackTrace: stack);
    return true;
  };

  AppLogger.d("Initializing UI and ScreenUtil...", tag: 'Main');
  await ScreenUtil.ensureScreenSize();
  Bloc.observer = const SimpleBlocObserver();

  // ── Appwrite (auth primary backend) ───────────────────────────────────────
  AppLogger.d("Initializing Appwrite and AppServices...", tag: 'Main');
  try {
    await initAppwrite();
    initMediaUploadService();
    AppServices.initialize();
    AppLogger.d("Backend services ready.", tag: 'Main');
  } catch (e, st) {
    AppLogger.e("WhatsUnity startup failed", tag: 'Main', error: e, stackTrace: st);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'WhatsUnity failed to start.\n\n$e\n\n'
                'If you are on web, rebuild with:\n'
                'flutter build web --release --csp '
                '--dart-define-from-file=.env\n'
                'For GitHub Pages project sites, also pass '
                '--base-href /YourRepoName/',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  AppLogger.d("Running MyApp.", tag: 'Main');
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
                remoteDataSource: AppwriteAuthRemoteDataSourceImpl(
                  account: appwriteAccount,
                  functions: appwriteFunctions,
                  tables: appwriteTables,
                  googleServerClientId: RuntimeEnv.googleServerClientId,
                  nativeGoogleBridgeFunctionId: RuntimeEnv.appwriteFunctionGoogleNativeSigninBridge,
                  oauthSuccessUrl: RuntimeEnv.appwriteOauthSuccess,
                  oauthFailureUrl: RuntimeEnv.appwriteOauthFailure,
                ),
                appwriteAccount: appwriteAccount,
                appwriteTables: appwriteTables, localDataSource: AuthLocalDataSourceImpl(
                databaseHelper: DatabaseHelper.instance,
              ),
              ),
            );
            // Preserved teardown-safe bootstrap — see MIGRATION_PLAN.md §2.3.
            authCubit.initializeAuthSession();
            return authCubit;
          },
        ),
        BlocProvider(create: (context) => AppCubit()),
        BlocProvider(create: (context) => ReportCubit(adminRepository: AppServices.adminRepository)),
        BlocProvider(create: (context) => AdminCubit(adminRepository: AppServices.adminRepository)),
        BlocProvider(create: (context) => PresenceCubit()),
        BlocProvider(create: (context) => ManagerCubit()),
        BlocProvider(create: (context) => ChatDetailsCubit(authCubit: context.read<AuthCubit>(), databases: appwriteTables)),
        BlocProvider(
          create: (context) {
            final authState = context.read<AuthCubit>().state;
            final members = (authState is Authenticated) ? authState.chatMembers : <ChatMember>[];
            return MessageReceiptsCubit(AppServices.chatRemoteDataSource, chatMembers: members);
          },
        ),
        BlocProvider(create: (context) => MentionNotificationCubit()),
        BlocProvider(
          create:
              (context) => MaintenanceCubit(
                repository: MaintenanceRepositoryImpl(
                  remoteDataSource: AppServices.maintenanceRemoteDataSource,
                  localDataSource: AppServices.maintenanceLocalDataSource,
                  syncRepository: AppServices.maintenanceSyncRepository,
                ),
              ),
        ),
        BlocProvider(create: (context) => SocialCubit(repository: SocialRepositoryImpl(remoteDataSource: SocialRemoteDataSourceImpl(databases: appwriteTables)))),
        BlocProvider(create: (context) => ProfileCubit()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          final prototypeRoutes = kDebugMode ? {'/uiux-prototypes': (_) => const UiUxPrototypeCatalogPage()} : <String, WidgetBuilder>{};
          return MaterialApp(
            title: 'WhatsUnity',
            debugShowCheckedModeBanner: false,
            theme: myLightTheme(),
            routes: prototypeRoutes,
            supportedLocales: L10n.all,
            localeResolutionCallback: (deviceLocale, supportedLocales) {
              if (deviceLocale != null && supportedLocales.any((l) => l.languageCode == deviceLocale.languageCode)) {
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
              ScreenUtil.init(context, designSize: const Size(360, 690), minTextAdapt: true, splitScreenMode: true);
              if (child == null) {
                return const SizedBox.shrink();
              }
              final mq = MediaQuery.of(context);
              return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3)), child: child);
            },
            home: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final authCubit = context.read<AuthCubit>();
                AppLogger.d("Routing Builder: state=${state.runtimeType}, userEmail=${authCubit.signupGoogleEmail}, signingGoogle=${authCubit.signInGoogle}", tag: 'Main');
                
                // 1. Prioritize authenticated/registered gate
                if (state is Authenticated || state is RegistrationSuccess) {
                  final bool isDataReady = (state is Authenticated) ? (state.role != null && state.selectedCompoundId != null) : true;
                  
                  // Reset registration flags if we are truly authenticated and ready
                  if (isDataReady && (authCubit.signupGoogleEmail != null || authCubit.signInGoogle)) {
                    AppLogger.d("User authenticated with data, forcing flag reset to exit registration UI", tag: 'Main');
                  }

                  ///Signing in with email address Or loggingIn during app start
                  if (authCubit.signupGoogleEmail == null && authCubit.signInGoogle == false && isDataReady) {
                    return AuthReadyGate(
                      key: ValueKey(authCubit.authSessionNonce),
                    );
                  }
                  
                  // If authenticated but data isn't ready (e.g. still in AuthLoading phase of initialization), 
                  // or if we are still technically in a "Google Signup" state despite being Authenticated,
                  // we check if we can skip the signup page.
                  if (isDataReady) {
                    return AuthReadyGate(
                      key: ValueKey(authCubit.authSessionNonce),
                    );
                  }

                  return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
                }

                // 2. Only show full-screen spinner if we have no UI to show yet
                if (state is AuthLoading && state.categories.isEmpty) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
                }

                if (state is SignUpSuccess) {
                   return const SignUp();
                }

                // Default to SignIn for Unauthenticated, AuthInitial, AuthError
                // If Google registration is pending AND profile is incomplete, show SignUp.
                if (state is GoogleSignupState || (authCubit.signupGoogleEmail != null && state is! Authenticated)) {
                  return const SignUp();
                }

                if (state is Unauthenticated || state is AuthInitial || state is AuthError) {
                   return authCubit.signInToggler ? const SignIn() : const SignUp();
                }

                return const SignIn();
              },
            ),
          );
        },
      ),
    );
  }
}
