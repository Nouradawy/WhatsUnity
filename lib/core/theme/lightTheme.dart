import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import '../../l10n/app_localizations.dart';



extension ContextThemeExtension on BuildContext {
  /// A shortcut to easily access the Theme.of(context) data.
  ThemeData get theme => Theme.of(this);
  AppTextTheme get txt =>
      Theme.of(this).extension<AppTextThemeExtension>()!.textTheme;
  AppLocalizations get loc => AppLocalizations.of(this)!;
}

// Define your light theme
 ThemeData myLightTheme() {
   return ThemeData(
     // 1. Set up the Color Scheme
     // ColorScheme.fromSeed is a great way to generate a full palette
     // from a single primary color.
     chipTheme: ChipThemeData(
       // This will apply to all chips in your app

       shape: RoundedRectangleBorder(
         side: BorderSide.none,
         borderRadius:  BorderRadius.circular(5),
       ),
       side: BorderSide.none,
       surfaceTintColor: Colors.transparent,

     ),
     colorScheme: ColorScheme.fromSeed(
       seedColor: HexColor("#dae7f7"),
       brightness: Brightness.light, // Specify this is a light theme
     ),

     // 2. Set up the Text Theme
     // You can set a default font for the whole app.
     fontFamily: GoogleFonts.manrope().fontFamily,

     // Or customize individual text styles.
     extensions: [
       AppTextThemeExtension(AppTextTheme.light()),
     ],

     useMaterial3: true,
   );
 }

class AppTextTheme {
  final TextStyle signInHeading1;
  final TextStyle signSubtitle;
  final TextStyle role;
  final TextStyle roleDescription;
  final TextStyle socialUserName;
  final TextStyle socialPostSince;
  final TextStyle socialPostHead;
  final TextStyle commentsCount;
  final TextStyle reportSubmissionButton;
  final TextStyle profileListHead;
  final TextStyle userNameCard;
  final TextStyle cardBody;
  final Color statusButtonColor;
  final Color socialBackgroundColor;
  final Color socialIconColor;

  AppTextTheme({
    required this.signInHeading1,
    required this.signSubtitle,
    required this.role,
    required this.roleDescription,
    required this.socialUserName,
    required this.socialPostSince,
    required this.socialPostHead,
    required this.commentsCount,
    required this.reportSubmissionButton,
    required this.profileListHead,
    required this.userNameCard,
    required this.cardBody,
    required this.statusButtonColor,
    required this.socialBackgroundColor,
    required this.socialIconColor,
});

  factory AppTextTheme.light() => AppTextTheme(
    signInHeading1: GoogleFonts.manrope(
      fontSize: 25,
      fontWeight: FontWeight.w900,
      color: HexColor("#111418"),
    ),
      signSubtitle: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: HexColor("#637488"),
    ),
    role: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
    roleDescription: GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: HexColor("#637488"),
    ),
    socialUserName:GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w900,
      fontSize: 12,
    ),
    socialPostSince:GoogleFonts.plusJakartaSans(
      height: 0.8,
      fontWeight: FontWeight.w300,
      fontSize: 12,
    ),
    socialPostHead: GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w500,
      fontSize: 12,
      color: Colors.black,
    ),
    commentsCount:GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: HexColor("#1c1e21").withAlpha(170),
      ),
    userNameCard: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: HexColor("#1c1e21").withAlpha(170),
    ),
    cardBody: GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.black87),
    reportSubmissionButton: GoogleFonts.plusJakartaSans(color: Colors.white , fontWeight: FontWeight.w600),
    profileListHead: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700 ,fontSize: 12 , color: Colors.grey),

    statusButtonColor: HexColor("#F0F2F5"),
    socialBackgroundColor: HexColor("#F0EFF4"),
    socialIconColor: HexColor("#1c1e21").withAlpha(170),

  );
}

@immutable
class AppTextThemeExtension extends ThemeExtension<AppTextThemeExtension> {
  final AppTextTheme textTheme;

  const AppTextThemeExtension(this.textTheme);

  @override
  AppTextThemeExtension copyWith({AppTextTheme? textTheme}) {
    return AppTextThemeExtension(textTheme ?? this.textTheme);
  }

  @override
  AppTextThemeExtension lerp(AppTextThemeExtension? other, double t) {
    if (other == null) return this;
    return AppTextThemeExtension(textTheme);
  }
}