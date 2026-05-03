import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:WhatsUnity/Layout/Cubit/cubit.dart';
import 'package:WhatsUnity/core/utils/app_logger.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/auth/presentation/pages/otp_screen.dart';
import 'package:WhatsUnity/features/auth/presentation/pages/signin_page.dart';
import '../widgets/signup_sections.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController fullName = TextEditingController();
  final TextEditingController displayName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController buildingNum = TextEditingController();
  final TextEditingController apartmentNum = TextEditingController();
  final TextEditingController phoneNumber = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  @override
  void dispose() {
    fullName.dispose();
    displayName.dispose();
    email.dispose();
    password.dispose();
    buildingNum.dispose();
    apartmentNum.dispose();
    phoneNumber.dispose();
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
        ///Signing up with email address
        if (state is SignUpSuccess) {
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const OtpScreen().copyWithEmail(state.email)),
          );
        }
        /// When registering with google signup and clicked continue Registration
        if (state is RegistrationSuccess) {
          context.read<AppCubit>().bottomNavIndexChange(0);
        }
        if (state is AuthError) {
          AppLogger.e(state.message, tag: 'SignUpPage');
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
        if (cubit.signupGoogleUserName != null && displayName.text.isEmpty) {
          displayName.text = cubit.signupGoogleUserName!;
        }

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
                          const SizedBox(height: 40),
                          SignupHeadingSection(isSignIn: false),
                          const SizedBox(height: 30),
                          SignupCredentialsFormSection(
                            email: email,
                            fullName: fullName,
                            displayName: displayName,
                            password: password,
                            phoneNumber: phoneNumber,
                            formKey: _formKey1,
                            isSignIn: false,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.only(
                              left: MediaQuery.of(context).size.width * 0.075,
                            ),
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              "Select Your Role",
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: HexColor("#111418"),
                              ),
                            ),
                          ),
                          roleSelection(
                            context,
                            buildingNum,
                            apartmentNum,
                            _formKey2,
                            _formKey3,
                          ),
                          const SizedBox(height: 20),
                          if (cubit.signupGoogleEmail == null)
                            SignupSubmitSection(
                              email: email,
                              fullName: fullName,
                              displayName: displayName,
                              password: password,
                              buildingNum: buildingNum,
                              apartmentNum: apartmentNum,
                              phoneNumber: phoneNumber,
                              formKey1: _formKey1,
                              formKey2: _formKey2,
                              isSignIn: false,
                            ),
                          SignupProvidersSection(
                            fullName: fullName,
                            buildingNum: buildingNum,
                            apartmentNum: apartmentNum,
                            phoneNumber: phoneNumber,
                            userName: displayName,
                            formKey1: _formKey1,
                            formKey2: _formKey2,
                            isSignIn: false,
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
                      isSignIn: false,
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
