import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:WhatsUnity/Layout/Cubit/cubit.dart';
import 'package:WhatsUnity/core/utils/app_logger.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/auth/presentation/pages/signup_page.dart';
import '../widgets/signup_sections.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          final cubit = context.read<AuthCubit>();
          if (cubit.signInGoogle || cubit.signupGoogleEmail != null) return;
          if (state.role == null) return;
          context.read<AppCubit>().bottomNavIndexChange(0);
        }
        if (state is AuthError) {
          AppLogger.e(state.message, tag: 'SignInPage');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.pink,
              behavior: SnackBarBehavior.floating,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(width: 8),
                  Flexible(child: Text(state.message)),
                ],
              ),
            ),
          );
        }
      },
      builder: (BuildContext context, state) {
        final cubit = context.read<AuthCubit>();
        return GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
          child: Scaffold(
            backgroundColor: HexColor("#f9f9f9"),
            body: SafeArea(
              child: Stack(
                alignment: AlignmentDirectional.center,
                fit: StackFit.expand,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 100),
                          SignupHeadingSection(isSignIn: true),
                          const SizedBox(height: 50),
                          SignupCredentialsFormSection(
                            email: email,
                            password: password,
                            formKey: _formKey1,
                            isSignIn: true,
                          ),
                          const SizedBox(height: 30),
                          SignupSubmitSection(
                            email: email,
                            password: password,
                            formKey1: _formKey1,
                            isSignIn: true,
                          ),
                          SignupProvidersSection(
                            formKey1: _formKey1,
                            isSignIn: true,
                          ),
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: footer(
                      context,
                      isSignIn: true,
                      onToggle: () => cubit.toggleSignIn(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
