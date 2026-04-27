import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// the current Language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language;

  /// No description provided for @signInHeading1.
  ///
  /// In en, this message translates to:
  /// **'Log In Your Account'**
  String get signInHeading1;

  /// No description provided for @signUpHeading1.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get signUpHeading1;

  /// No description provided for @signSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join our vibrant residential community.'**
  String get signSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signUpFooter.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get signUpFooter;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'UserName'**
  String get displayName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @roleSelection.
  ///
  /// In en, this message translates to:
  /// **'Select Your Role'**
  String get roleSelection;

  /// No description provided for @residentRole.
  ///
  /// In en, this message translates to:
  /// **'Resident'**
  String get residentRole;

  /// No description provided for @residentRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'I live in the community.'**
  String get residentRoleDescription;

  /// No description provided for @managerRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'I manage the community.'**
  String get managerRoleDescription;

  /// No description provided for @managerRole.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get managerRole;

  /// No description provided for @forgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordQuestion;

  /// No description provided for @haveAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountQuestion;

  /// No description provided for @signUpQuestion.
  ///
  /// In en, this message translates to:
  /// **'Haven\'t signed up yet?'**
  String get signUpQuestion;

  /// No description provided for @signUpAddCompound.
  ///
  /// In en, this message translates to:
  /// **'Select Compound'**
  String get signUpAddCompound;

  /// No description provided for @signUpBuildingNumber.
  ///
  /// In en, this message translates to:
  /// **'Building Number'**
  String get signUpBuildingNumber;

  /// No description provided for @signUpApartmentNumber.
  ///
  /// In en, this message translates to:
  /// **'apartment Number'**
  String get signUpApartmentNumber;

  /// No description provided for @apartmentConflict1.
  ///
  /// In en, this message translates to:
  /// **'This apartment is already registered under someone else account.'**
  String get apartmentConflict1;

  /// No description provided for @apartmentConflict2.
  ///
  /// In en, this message translates to:
  /// **'make sure you attach the proof of resident , so we can investigate this'**
  String get apartmentConflict2;

  /// No description provided for @apartmentConflict3.
  ///
  /// In en, this message translates to:
  /// **'we can\'t continue signup without uploading proof of resident'**
  String get apartmentConflict3;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @cleaning.
  ///
  /// In en, this message translates to:
  /// **'Care service'**
  String get cleaning;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @socialTab.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get socialTab;

  /// No description provided for @chatTab.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTab;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @statusButton.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get statusButton;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @commentAs.
  ///
  /// In en, this message translates to:
  /// **'Comment as'**
  String get commentAs;

  /// No description provided for @postCreate.
  ///
  /// In en, this message translates to:
  /// **'Create post'**
  String get postCreate;

  /// No description provided for @maintenanceListError.
  ///
  /// In en, this message translates to:
  /// **'Maintenance category list cannot be empty'**
  String get maintenanceListError;

  /// No description provided for @maintenanceReport.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Report'**
  String get maintenanceReport;

  /// No description provided for @maintenanceIssueSelect.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get maintenanceIssueSelect;

  /// No description provided for @issueDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue in detail'**
  String get issueDescription;

  /// No description provided for @issueTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get issueTitle;

  /// No description provided for @uploadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Upload Photos'**
  String get uploadPhotos;

  /// No description provided for @emptyPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos uploaded'**
  String get emptyPhotos;

  /// No description provided for @uploadPhotosLabel.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload photos of the issue'**
  String get uploadPhotosLabel;

  /// No description provided for @uploadPhotosPosts.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload photos'**
  String get uploadPhotosPosts;

  /// No description provided for @uploadPhotosVerFiles.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload photos for verification'**
  String get uploadPhotosVerFiles;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @reportSubmission.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get reportSubmission;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reportHistory.
  ///
  /// In en, this message translates to:
  /// **'Report History'**
  String get reportHistory;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblem;

  /// No description provided for @issue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get issue;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @inProcess.
  ///
  /// In en, this message translates to:
  /// **'In Process'**
  String get inProcess;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @newBrainStorm.
  ///
  /// In en, this message translates to:
  /// **'BrainStorming'**
  String get newBrainStorm;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'privacy and policy'**
  String get privacy_policy;

  /// No description provided for @terms_conditions.
  ///
  /// In en, this message translates to:
  /// **'terms and conditions'**
  String get terms_conditions;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @ownerShip_proof.
  ///
  /// In en, this message translates to:
  /// **'Ownership proof'**
  String get ownerShip_proof;

  /// No description provided for @ownerShipType.
  ///
  /// In en, this message translates to:
  /// **'Ownership type'**
  String get ownerShipType;

  /// No description provided for @rental.
  ///
  /// In en, this message translates to:
  /// **'Rental'**
  String get rental;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get add;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copyReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy report details'**
  String get copyReportDetails;

  /// No description provided for @reportDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Report details copied.'**
  String get reportDetailsCopied;

  /// No description provided for @directMessagingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Direct messaging is not available yet in this build.'**
  String get directMessagingUnavailable;

  /// No description provided for @profileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}'**
  String profileLabel(Object name);

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get noPostsYet;

  /// No description provided for @noAnnouncementsYet.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet.'**
  String get noAnnouncementsYet;

  /// No description provided for @likedPost.
  ///
  /// In en, this message translates to:
  /// **'Liked post'**
  String get likedPost;

  /// No description provided for @postReferenceCopied.
  ///
  /// In en, this message translates to:
  /// **'Post reference copied to clipboard.'**
  String get postReferenceCopied;

  /// No description provided for @noReportsFound.
  ///
  /// In en, this message translates to:
  /// **'No reports found.'**
  String get noReportsFound;

  /// No description provided for @noRequestsFoundForFilter.
  ///
  /// In en, this message translates to:
  /// **'No requests found for this filter.'**
  String get noRequestsFoundForFilter;

  /// No description provided for @createAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Create Announcement'**
  String get createAnnouncement;

  /// No description provided for @announcementPublishingSoon.
  ///
  /// In en, this message translates to:
  /// **'Announcement publishing will be added next.'**
  String get announcementPublishingSoon;

  /// No description provided for @messageAction.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageAction;

  /// No description provided for @viewProfileAction.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfileAction;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @madeBy.
  ///
  /// In en, this message translates to:
  /// **'Made by'**
  String get madeBy;

  /// No description provided for @reportedUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported User ID: {id}'**
  String reportedUserIdLabel(Object id);

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonLabel(Object reason);

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description: {description}'**
  String descriptionLabel(Object description);

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateLabel(Object date);

  /// No description provided for @noCommunitySelected.
  ///
  /// In en, this message translates to:
  /// **'No community selected'**
  String get noCommunitySelected;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to record audio.'**
  String get microphonePermissionRequired;

  /// No description provided for @brainStormingTitle.
  ///
  /// In en, this message translates to:
  /// **'Brain Storming'**
  String get brainStormingTitle;

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createNew;

  /// No description provided for @noBrainstormsYet.
  ///
  /// In en, this message translates to:
  /// **'No Brainstorms yet'**
  String get noBrainstormsYet;

  /// No description provided for @pollNotEnoughOptions.
  ///
  /// In en, this message translates to:
  /// **'This poll does not have enough options to display.'**
  String get pollNotEnoughOptions;

  /// No description provided for @voteBodyRequired.
  ///
  /// In en, this message translates to:
  /// **'Vote body cannot be empty'**
  String get voteBodyRequired;

  /// No description provided for @voteBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Vote body'**
  String get voteBodyLabel;

  /// No description provided for @atLeastTwoOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'At least 2 options are required'**
  String get atLeastTwoOptionsRequired;

  /// No description provided for @thisOptionIsRequired.
  ///
  /// In en, this message translates to:
  /// **'This option is required'**
  String get thisOptionIsRequired;

  /// No description provided for @pleaseFillAtLeastTwoOptions.
  ///
  /// In en, this message translates to:
  /// **'Please fill at least 2 options'**
  String get pleaseFillAtLeastTwoOptions;

  /// No description provided for @generalChatLabel.
  ///
  /// In en, this message translates to:
  /// **'GENERAL CHAT'**
  String get generalChatLabel;

  /// No description provided for @groupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupLabel;

  /// No description provided for @membersCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCountLabel(Object count);

  /// No description provided for @muteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute Notifications'**
  String get muteNotifications;

  /// No description provided for @addNewSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Add new suggestion'**
  String get addNewSuggestion;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @whatsapp.
  ///
  /// In en, this message translates to:
  /// **'Whatsapp'**
  String get whatsapp;

  /// No description provided for @lastSeenTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Last Seen today at {time}'**
  String lastSeenTodayAt(Object time);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @submitAction.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitAction;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This will open your email app to request deletion.'**
  String get deleteAccountMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @supportWhatsUnity.
  ///
  /// In en, this message translates to:
  /// **'Support WhatsUnity'**
  String get supportWhatsUnity;

  /// No description provided for @donationMessage.
  ///
  /// In en, this message translates to:
  /// **'Your donations help keep our servers running and the app ad-free.'**
  String get donationMessage;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @donateNow.
  ///
  /// In en, this message translates to:
  /// **'Donate Now'**
  String get donateNow;

  /// No description provided for @donateToCommunity.
  ///
  /// In en, this message translates to:
  /// **'Donate to Community'**
  String get donateToCommunity;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountSection;

  /// No description provided for @preferencesSection.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferencesSection;

  /// No description provided for @supportLegalSection.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & LEGAL'**
  String get supportLegalSection;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @noCompoundSelected.
  ///
  /// In en, this message translates to:
  /// **'No compound selected'**
  String get noCompoundSelected;

  /// No description provided for @submittedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Submitted Documents'**
  String get submittedDocuments;

  /// No description provided for @cancelRegistration.
  ///
  /// In en, this message translates to:
  /// **'Cancel Registration'**
  String get cancelRegistration;

  /// No description provided for @joinCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join a Community'**
  String get joinCommunity;

  /// No description provided for @unknownState.
  ///
  /// In en, this message translates to:
  /// **'Unknown State'**
  String get unknownState;

  /// No description provided for @userManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// No description provided for @verificationRequests.
  ///
  /// In en, this message translates to:
  /// **'Verification Requests'**
  String get verificationRequests;

  /// No description provided for @userReports.
  ///
  /// In en, this message translates to:
  /// **'User Reports'**
  String get userReports;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
