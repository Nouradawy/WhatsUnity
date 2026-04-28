import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:WhatsUnity/Layout/Cubit/cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/auth/presentation/pages/otp_screen.dart';
import 'package:WhatsUnity/features/home/presentation/pages/main_screen.dart';
import '../../../../core/services/PresenceManager.dart';
import '../widgets/signup_sections.dart';

class SignUp extends StatelessWidget {
  SignUp({super.key});
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
  Widget build(BuildContext context) {

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          final cubit = context.read<AuthCubit>();
          // During Google sign-up, stay on this page until completeRegistration succeeds.
          if (cubit.signInGoogle) return;
          context.read<AuthCubit>().presetBeforeSignin().then((_) {
            // Root [MyApp] may already have swapped SignUp for [AuthReadyGate];
            // this context is then unmounted and Navigator must not run.
            if (!context.mounted) return;
            context.read<AppCubit>().bottomNavIndexChange(0);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PresenceManager(child: MainScreen()),
              ),
            );
          }).catchError((Object e, StackTrace st) {
            debugPrint(
              'SignUp: presetBeforeSignin after Authenticated failed: $e\n$st',
            );
          });
        }
        if (state is SignUpSuccess) {
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const OtpScreen().copyWithEmail(state.email)),
          );
        }
        if (state is RegistrationSuccess) {
          context.read<AuthCubit>().presetBeforeSignin().then((_) {
            if (!context.mounted) return;
            context.read<AppCubit>().bottomNavIndexChange(0);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => PresenceManager(child: MainScreen()),
              ),
            );
          }).catchError((Object e, StackTrace st) {
            debugPrint(
              'SignUp: presetBeforeSignin after RegistrationSuccess failed: '
              '$e\n$st',
            );
          });
        }
        if (state is AuthError) {
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
                          SignupHeadingSection(),
                          const SizedBox(height: 30),
                          SignupCredentialsFormSection(
                            email: email,
                            fullName: fullName,
                            displayName: displayName,
                            password: password,
                            phoneNumber: phoneNumber,
                            formKey: _formKey1,
                          ),
                          if (cubit.signInToggler == false)
                            Column(
                              children: [
                                const SizedBox(height: 20),
                                Container(
                                  padding: EdgeInsets.only(
                                    left: MediaQuery.of(context).size.width *
                                        0.075,
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
                                SignupRoleSection(
                                  buildingNum: buildingNum,
                                  apartmentNum: apartmentNum,
                                  roleFormKey: _formKey2,
                                  managerFormKey: _formKey3,
                                ),
                              ],
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
                            ),
                          SignupProvidersSection(
                            fullName: fullName,
                            buildingNum: buildingNum,
                            apartmentNum: apartmentNum,
                            phoneNumber: phoneNumber,
                            userName: displayName,
                            formKey1: _formKey1,
                            formKey2: _formKey2,
                          ),
                          const SizedBox(
                            height: 70,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(bottom: 0, child: footer(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
