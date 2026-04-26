import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/constants/Constants.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/pages/welcome_page.dart';

Future<void> newCompound(BuildContext context) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        content: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          width: MediaQuery.sizeOf(context).width * 0.8,
          child: const JoinCommunity(
            atWelcome: true,
          ),
        ),
      );
    },
  );
}

Column heading(BuildContext context) {
  final cubit = context.read<AuthCubit>();
  return Column(
    children: [
      Text(
        cubit.signInToggler ? context.loc.signInHeading1 : context.loc.signUpHeading1,
        style: context.txt.signInHeading1,
      ),
      const SizedBox(height: 5),
      Text(context.loc.signSubtitle, style: context.txt.signSubtitle),
    ],
  );
}

Column roleSelection(
  BuildContext context,
  TextEditingController buildingNum,
  TextEditingController apartmentNum,
  GlobalKey formKey2,
  GlobalKey formKey3,
) {
  final cubit = context.read<AuthCubit>();
  return Column(
    children: [
      const SizedBox(height: 20),
      if (cubit.roleName != Roles.manager)
        Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            border: cubit.roleName == Roles.user ? Border.all(color: Colors.black) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: MaterialButton(
            onPressed: () {
              if (cubit.selectedCompoundId != null) cubit.resetUserData();
              if (cubit.roleName != Roles.user) {
                cubit.changeRole(Roles.user);
              } else {
                cubit.changeRole(Roles.admin);
              }
            },
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.all(5),
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(color: HexColor("#dae7f7"), shape: BoxShape.circle),
                  child: SvgPicture.asset("assets/person.svg"),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.loc.residentRole, style: context.txt.role),
                      Text(context.loc.residentRoleDescription, style: context.txt.roleDescription),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 10),
      if (cubit.roleName != Roles.user)
        Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            border: cubit.roleName == Roles.manager ? Border.all(color: Colors.black) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: MaterialButton(
            onPressed: () {
              if (cubit.selectedCompoundId != null) cubit.resetUserData();
              if (cubit.roleName != Roles.manager) {
                cubit.changeRole(Roles.manager);
              } else {
                cubit.changeRole(Roles.admin);
              }
            },
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.all(5),
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(color: HexColor("#dae7f7"), shape: BoxShape.circle),
                  child: const Icon(Icons.work, size: 21),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.loc.managerRole, style: context.txt.role),
                      Text(context.loc.managerRoleDescription, style: context.txt.roleDescription),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      if (cubit.roleName == Roles.manager) managerInfo(context, formKey3),
      if (cubit.roleName == Roles.user) apartmentInfo(context, buildingNum, apartmentNum, formKey2),
    ],
  );
}

Form apartmentInfo(
  BuildContext context,
  TextEditingController buildingNum,
  TextEditingController apartmentNum,
  GlobalKey formKey2,
) {
  final cubit = context.read<AuthCubit>();
  return Form(
    key: formKey2,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 15,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          // spacing: MediaQuery.sizeOf(context).width * 0.10,
          children: [
            MaterialButton(
              padding: EdgeInsets.zero,
              height: 50,
              elevation: 0,
              color: HexColor("#dae7f7"),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              onPressed: () => newCompound(context),
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.80 / 2,
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  cubit.selectedCompoundId == null
                      ? context.loc.signUpAddCompound
                      : (cubit.myCompounds.isNotEmpty ? cubit.myCompounds.values.last.toString() : context.loc.signUpAddCompound),
                ),
              ),
            ),
            SegmentedButton<OwnerTypes>(
              selected: <OwnerTypes>{cubit.ownerType},
              onSelectionChanged: (Set<OwnerTypes> s) => cubit.changeOwnerType(s.first),
              segments: <ButtonSegment<OwnerTypes>>[
                ButtonSegment<OwnerTypes>(value: OwnerTypes.owner, label: Text(context.loc.owner)),
                ButtonSegment<OwnerTypes>(value: OwnerTypes.rental, label: Text(context.loc.rental)),
              ],
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          // spacing: MediaQuery.of(context).size.width * 0.05,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.80 / 2,
              child: defaultTextForm(
                context,
                controller: buildingNum,
                validation: (value) => (value == null || value.trim().isEmpty) ? "Building Number can't be Empty" : null,
                keyboardType: TextInputType.number,
                hintText: context.loc.signUpBuildingNumber,
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.80 / 2,
              child: defaultTextForm(
                context,
                controller: apartmentNum,
                validation: (value) {
                  if (value == null || value.trim().isEmpty) return "Apartment Number can't be Empty";
                  if (cubit.apartmentConflict) return "Apartment already taken";
                  return null;
                },
                keyboardType: TextInputType.number,
                hintText: context.loc.signUpApartmentNumber,
              ),
            ),
          ],
        ),
        _VerificationFilesWidget(cubit: cubit),
      ],
    ),
  );
}

Form managerInfo(BuildContext context, GlobalKey formKey3) {
  final cubit = context.read<AuthCubit>();
  return Form(
    key: formKey3,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 15,
      children: [
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: MaterialButton(
                padding: EdgeInsets.zero,
                height: 50,
                elevation: 0,
                color: HexColor("#dae7f7"),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                onPressed: () => newCompound(context),
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.80 / 2,
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    cubit.selectedCompoundId == null
                        ? context.loc.signUpAddCompound
                        : (cubit.myCompounds.isNotEmpty ? cubit.myCompounds.values.last.toString() : context.loc.signUpAddCompound),
                  ),
                ),
              ),
            ),
          ],
        ),
        _VerificationFilesWidget(cubit: cubit),
      ],
    ),
  );
}

class _VerificationFilesWidget extends StatelessWidget {
  final AuthCubit cubit;
  const _VerificationFilesWidget({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.topEnd,
      children: [
        SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.75,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: cubit.verFiles?.length ?? 0,
            itemBuilder: (context, index) {
              final imagePath = cubit.verFiles![index].path;
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black12,
                          child: Center(
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      )
                    : Image.file(File(imagePath), fit: BoxFit.cover),
              );
            },
          ),
        ),
        cubit.verFiles != null
            ? IconButton(onPressed: cubit.clearVerFiles, icon: const Icon(Icons.close))
            : DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  radius: const Radius.circular(8),
                  strokeWidth: 2,
                  color: Colors.grey.shade400,
                  dashPattern: const [5],
                ),
                child: Container(
                  alignment: AlignmentDirectional.center,
                  height: MediaQuery.sizeOf(context).height * 0.15,
                  width: MediaQuery.sizeOf(context).width * 0.8,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.loc.emptyPhotos, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                      Text(context.loc.uploadPhotosVerFiles, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400)),
                      MaterialButton(
                        onPressed: cubit.verFileImport,
                        color: HexColor("f0f2f5"),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Text(
                          context.loc.upload,
                          style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

Form form(
  BuildContext context,
  TextEditingController email,
  TextEditingController fullName,
  TextEditingController displayName,
  TextEditingController password,
  TextEditingController phoneNumber,
  GlobalKey formKey1,
) {
  final cubit = context.read<AuthCubit>();
  return Form(
    key: formKey1,
    child: Column(
      children: [
        if (!cubit.signInToggler) ...[
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: defaultTextForm(
              context,
              controller: fullName,
              validation: (value) => (value == null || value.trim().isEmpty) ? "Full Name can't be Empty" : null,
              keyboardType: TextInputType.name,
              labelText: context.loc.fullName,
              hintText: "Identical to your documents for verification ",
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: defaultTextForm(
              context,
              controller: displayName,
              validation: (value) => (value == null || value.trim().isEmpty) ? "Username can't be Empty" : null,
              keyboardType: TextInputType.text,
              labelText: context.loc.displayName,
              hintText: context.loc.displayName,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (cubit.signupGoogleEmail == null)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: defaultTextForm(
              context,
              controller: email,
              validation: (value) => (value == null || value.trim().isEmpty) ? "email address can't be Empty" : null,
              keyboardType: TextInputType.emailAddress,
              labelText: context.loc.emailAddress,
              hintText: context.loc.emailAddress,
            ),
          ),
        if (cubit.signupGoogleEmail != null)
          Container(
            padding: const EdgeInsets.only(right: 30, left: 10),
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            width: MediaQuery.of(context).size.width * 0.85,
            height: 45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cubit.signupGoogleEmail!,
                  style: GoogleFonts.manrope(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Icon(Icons.check_circle, color: Colors.greenAccent),
              ],
            ),
          ),
        if (cubit.signupGoogleEmail == null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: defaultTextForm(
              context,
              controller: password,
              validation: (value) => (value == null || value.trim().isEmpty) ? "password can't be Empty" : null,
              keyboardType: TextInputType.text,
              labelText: context.loc.password,
              hintText: context.loc.password,
              IsPassword: true,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (!cubit.signInToggler)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: defaultTextForm(
              context,
              controller: phoneNumber,
              validation: (value) => (value == null || value.trim().isEmpty) ? "phoneNumber can't be Empty" : null,
              keyboardType: TextInputType.number,
              labelText: context.loc.phoneNumber,
              hintText: "Whatsapp phone number",
            ),
          ),
      ],
    ),
  );
}

Column submitButton(
  BuildContext buildContext,
  TextEditingController email,
  TextEditingController fullName,
  TextEditingController displayName,
  TextEditingController password,
  TextEditingController buildingNum,
  TextEditingController apartmentNum,
  TextEditingController phoneNumber,
  GlobalKey<FormState> formKey1,
  GlobalKey<FormState> formKey2,
) {
  final cubit = buildContext.read<AuthCubit>();
  return Column(
    children: [
      if ((cubit.apartmentConflict && !cubit.signInToggler && cubit.roleName != Roles.manager) ||
          (cubit.apartmentConflict && cubit.verFiles == null && cubit.signingIn && !cubit.signInToggler && cubit.roleName != Roles.manager)) ...[
        Text(buildContext.loc.apartmentConflict1, style: buildContext.txt.signSubtitle.copyWith(color: Colors.pinkAccent, fontWeight: FontWeight.w400)),
        Text(buildContext.loc.apartmentConflict2, style: buildContext.txt.signSubtitle.copyWith(color: Colors.pinkAccent, fontWeight: FontWeight.w400)),
        if (cubit.verFiles == null)
          Text(buildContext.loc.apartmentConflict3, style: buildContext.txt.signSubtitle.copyWith(color: Colors.pinkAccent, fontWeight: FontWeight.w400)),
      ],
      Container(
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(buildContext).size.width * 0.075),
        child: MaterialButton(
          elevation: 0,
          color: HexColor("#dae7f7"),
          enableFeedback: cubit.signingIn,
          disabledColor: Colors.grey,
          onPressed: cubit.signingIn
              ? null
              : () async {
                  if (!cubit.signInToggler) {
                    // formKey1: full name, email, password, phone, etc. (always mounted)
                    final isForm1Valid = formKey1.currentState?.validate() ?? false;
                    if (!isForm1Valid) return;

                    if (cubit.roleName != Roles.manager) {
                      // formKey2: building / apartment (only mounted for resident flow)
                      final isForm2Valid = formKey2.currentState?.validate() ?? false;
                      if (!isForm2Valid) return;
                      await cubit.isApartmentTaken(
                        compoundId: cubit.selectedCompoundId!,
                        buildingName: buildingNum.text,
                        apartmentNum: apartmentNum.text,
                      );
                      final building = buildingNum.text.trim();
                      final apartment = apartmentNum.text.trim();
                      if (cubit.selectedCompoundId == null || building.isEmpty || apartment.isEmpty) {
                        if (!buildContext.mounted) return;
                        ScaffoldMessenger.of(buildContext)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(cubit.selectedCompoundId == null ? 'Please select a compound.' : 'Building and apartment are required.'),
                            ),
                          );
                        return;
                      }
                    }
                    cubit.signInSwitcher();
                    await cubit.signUp(
                      email: email.text,
                      password: password.text,
                      data: {
                        "display_name": displayName.text.trim(),
                        "full_name": fullName.text.trim(),
                        "role_id": cubit.roleName!.index + 1,
                        'compound_id': cubit.selectedCompoundId.toString(),
                        'building_num': cubit.roleName != Roles.manager ? buildingNum.text : '-1',
                        'apartment_num': cubit.roleName != Roles.manager ? apartmentNum.text : '-1',
                        "ownerType": cubit.ownerType.name,
                        "phoneNumber": phoneNumber.text,
                      },
                    );
                    cubit.signInSwitcher();
                    return;
                  }
                  cubit.signInSwitcher();
                  await cubit.signInWithPassword(email: email.text, password: password.text);
                  cubit.signInSwitcher();
                },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          child: SizedBox(
            width: double.infinity,
            height: 45,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  if (cubit.signingIn)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
                  Text(
                    cubit.signInToggler ? buildContext.loc.signIn : buildContext.loc.signUp,
                    style: buildContext.txt.role.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Column signInProviders(
  BuildContext context,
  TextEditingController fullName,
  TextEditingController buildingNum,
  TextEditingController apartmentNum,
  TextEditingController phoneNumber,
  TextEditingController userName,
  GlobalKey<FormState> formKey1,
  GlobalKey<FormState> formKey2,
) {
  final cubit = context.read<AuthCubit>();
  return Column(
    children: [
      if (cubit.signupGoogleEmail == null)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: const Text("or", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
        ),
      Container(
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.075),
        child: MaterialButton(
          height: 40,
          elevation: 0,
          disabledColor: Colors.grey.shade200,
          onPressed: cubit.googleSigningIn
              ? null
              : () async {
                  cubit.googleSignInSwitcher();
                  try {
                    if (cubit.signInToggler) {
                      await cubit.resetUserData();
                      await cubit.signInWithGoogle(isSignin: true);
                    } else if (cubit.signupGoogleEmail == null) {
                      await cubit.resetUserData();
                      await cubit.signInWithGoogle(isSignin: false);
                    } else {
                      final selectedRole = cubit.roleName;
                      final selectedCompoundId = cubit.selectedCompoundId;
                      if (selectedRole == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Please select your role before continuing.'),
                            ),
                          );
                        return;
                      }
                      if (selectedCompoundId == null || selectedCompoundId.isEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Please select your compound before continuing.'),
                            ),
                          );
                        return;
                      }

                      if (cubit.roleName != Roles.manager) {
                        final isForm1Valid = formKey1.currentState?.validate() ?? false;
                        final isForm2Valid = formKey2.currentState?.validate() ?? false;
                        if (!isForm1Valid || !isForm2Valid) return;
                        await cubit.isApartmentTaken(
                          compoundId: selectedCompoundId,
                          buildingName: buildingNum.text,
                          apartmentNum: apartmentNum.text,
                        );
                        if (cubit.apartmentConflict) return;
                      }
                      await cubit.completeRegistration(
                        fullName: fullName.text,
                        userName: userName.text,
                        ownerType: cubit.ownerType,
                        phoneNumber: phoneNumber.text,
                        roleId: selectedRole.index + 1,
                        buildingName: selectedRole != Roles.manager ? buildingNum.text : '-1',
                        apartmentNum: selectedRole != Roles.manager ? apartmentNum.text : '-1',
                        compoundId: selectedCompoundId,
                      );
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.pink,
                          content: Text('Google registration failed: $e'),
                        ),
                      );
                  } finally {
                    if (cubit.googleSigningIn) {
                      cubit.googleSignInSwitcher();
                    }
                  }
                },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.black26, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 15,
            children: [
              if (cubit.googleSigningIn)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
              Image.asset("assets/Google_icon-may25.webp", height: 25),
              Text(
                cubit.signupGoogleEmail != null
                    ? "Continue Google Registration"
                    : cubit.signInToggler
                        ? "Sign in with Google"
                        : "Register with Google",
              ),
            ],
          ),
        ),
      ),
      if (cubit.signupGoogleEmail != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.075),
          child: MaterialButton(
            height: 40,
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Colors.black26, width: 1),
            ),
            onPressed: () async {
              await cubit.cancelPendingGoogleRegistration();
            },
            child: const Text("Cancel Registration"),
          ),
        ),
    ],
  );
}

Container footer(BuildContext context) {
  final cubit = context.read<AuthCubit>();
  return Container(
    color: Colors.grey.shade50,
    width: MediaQuery.of(context).size.width,
    height: 60,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            style: context.txt.signSubtitle,
            children: <TextSpan>[
              TextSpan(
                text: cubit.signInToggler ? context.loc.signUpQuestion : context.loc.haveAccountQuestion,
              ),
              TextSpan(
                text: cubit.signInToggler ? " ${context.loc.signUpFooter}" : " ${context.loc.signIn}",
                style: context.txt.signSubtitle.copyWith(color: Colors.blue, fontWeight: FontWeight.w800),
                recognizer: TapGestureRecognizer()..onTap = cubit.toggleSignIn,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SignupHeadingSection extends StatelessWidget {
  const SignupHeadingSection({super.key});

  @override
  Widget build(BuildContext context) => heading(context);
}

class SignupCredentialsFormSection extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController fullName;
  final TextEditingController displayName;
  final TextEditingController password;
  final TextEditingController phoneNumber;
  final GlobalKey<FormState> formKey;

  const SignupCredentialsFormSection({
    super.key,
    required this.email,
    required this.fullName,
    required this.displayName,
    required this.password,
    required this.phoneNumber,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return form(
      context,
      email,
      fullName,
      displayName,
      password,
      phoneNumber,
      formKey,
    );
  }
}

class SignupRoleSection extends StatelessWidget {
  final TextEditingController buildingNum;
  final TextEditingController apartmentNum;
  final GlobalKey<FormState> roleFormKey;
  final GlobalKey<FormState> managerFormKey;

  const SignupRoleSection({
    super.key,
    required this.buildingNum,
    required this.apartmentNum,
    required this.roleFormKey,
    required this.managerFormKey,
  });

  @override
  Widget build(BuildContext context) {
    return roleSelection(
      context,
      buildingNum,
      apartmentNum,
      roleFormKey,
      managerFormKey,
    );
  }
}

class SignupSubmitSection extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController fullName;
  final TextEditingController displayName;
  final TextEditingController password;
  final TextEditingController buildingNum;
  final TextEditingController apartmentNum;
  final TextEditingController phoneNumber;
  final GlobalKey<FormState> formKey1;
  final GlobalKey<FormState> formKey2;

  const SignupSubmitSection({
    super.key,
    required this.email,
    required this.fullName,
    required this.displayName,
    required this.password,
    required this.buildingNum,
    required this.apartmentNum,
    required this.phoneNumber,
    required this.formKey1,
    required this.formKey2,
  });

  @override
  Widget build(BuildContext context) {
    return submitButton(
      context,
      email,
      fullName,
      displayName,
      password,
      buildingNum,
      apartmentNum,
      phoneNumber,
      formKey1,
      formKey2,
    );
  }
}

class SignupProvidersSection extends StatelessWidget {
  final TextEditingController fullName;
  final TextEditingController buildingNum;
  final TextEditingController apartmentNum;
  final TextEditingController phoneNumber;
  final TextEditingController userName;
  final GlobalKey<FormState> formKey1;
  final GlobalKey<FormState> formKey2;

  const SignupProvidersSection({
    super.key,
    required this.fullName,
    required this.buildingNum,
    required this.apartmentNum,
    required this.phoneNumber,
    required this.userName,
    required this.formKey1,
    required this.formKey2,
  });

  @override
  Widget build(BuildContext context) {
    return signInProviders(
      context,
      fullName,
      buildingNum,
      apartmentNum,
      phoneNumber,
      userName,
      formKey1,
      formKey2,
    );
  }
}

