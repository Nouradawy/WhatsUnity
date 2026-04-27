// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'English';

  @override
  String get signInHeading1 => 'Log In Your Account';

  @override
  String get signUpHeading1 => 'Create Your Account';

  @override
  String get signSubtitle => 'Join our vibrant residential community.';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signUpFooter => 'Create an account';

  @override
  String get fullName => 'Full Name';

  @override
  String get displayName => 'UserName';

  @override
  String get emailAddress => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get roleSelection => 'Select Your Role';

  @override
  String get residentRole => 'Resident';

  @override
  String get residentRoleDescription => 'I live in the community.';

  @override
  String get managerRoleDescription => 'I manage the community.';

  @override
  String get managerRole => 'Manager';

  @override
  String get forgotPasswordQuestion => 'Forgot Password?';

  @override
  String get haveAccountQuestion => 'Already have an account?';

  @override
  String get signUpQuestion => 'Haven\'t signed up yet?';

  @override
  String get signUpAddCompound => 'Select Compound';

  @override
  String get signUpBuildingNumber => 'Building Number';

  @override
  String get signUpApartmentNumber => 'apartment Number';

  @override
  String get apartmentConflict1 =>
      'This apartment is already registered under someone else account.';

  @override
  String get apartmentConflict2 =>
      'make sure you attach the proof of resident , so we can investigate this';

  @override
  String get apartmentConflict3 =>
      'we can\'t continue signup without uploading proof of resident';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get security => 'Security';

  @override
  String get cleaning => 'Care service';

  @override
  String get announcements => 'Announcements';

  @override
  String get socialTab => 'Social';

  @override
  String get chatTab => 'Chat';

  @override
  String get homeTab => 'Home';

  @override
  String get profileTab => 'Profile';

  @override
  String get settingsTab => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get home => 'Home';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get statusButton => 'What\'s on your mind?';

  @override
  String get comment => 'Comment';

  @override
  String get like => 'Like';

  @override
  String get share => 'Share';

  @override
  String get commentAs => 'Comment as';

  @override
  String get postCreate => 'Create post';

  @override
  String get maintenanceListError =>
      'Maintenance category list cannot be empty';

  @override
  String get maintenanceReport => 'Maintenance Report';

  @override
  String get maintenanceIssueSelect => 'Category';

  @override
  String get issueDescription => 'Describe the issue in detail';

  @override
  String get issueTitle => 'Title';

  @override
  String get uploadPhotos => 'Upload Photos';

  @override
  String get emptyPhotos => 'No photos uploaded';

  @override
  String get uploadPhotosLabel => 'Tap to upload photos of the issue';

  @override
  String get uploadPhotosPosts => 'Tap to upload photos';

  @override
  String get uploadPhotosVerFiles => 'Tap to upload photos for verification';

  @override
  String get upload => 'Upload';

  @override
  String get reportSubmission => 'Submit Report';

  @override
  String get report => 'Report';

  @override
  String get reportHistory => 'Report History';

  @override
  String get reportProblem => 'Report a Problem';

  @override
  String get issue => 'Issue';

  @override
  String get date => 'Date';

  @override
  String get inProcess => 'In Process';

  @override
  String get completed => 'Completed';

  @override
  String get newBrainStorm => 'BrainStorming';

  @override
  String get privacy_policy => 'privacy and policy';

  @override
  String get terms_conditions => 'terms and conditions';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get ownerShip_proof => 'Ownership proof';

  @override
  String get ownerShipType => 'Ownership type';

  @override
  String get rental => 'Rental';

  @override
  String get owner => 'Owner';

  @override
  String get add => 'New';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get close => 'Close';

  @override
  String get copyReportDetails => 'Copy report details';

  @override
  String get reportDetailsCopied => 'Report details copied.';

  @override
  String get directMessagingUnavailable =>
      'Direct messaging is not available yet in this build.';

  @override
  String profileLabel(Object name) {
    return 'Profile: $name';
  }

  @override
  String get noPostsYet => 'No posts yet.';

  @override
  String get noAnnouncementsYet => 'No announcements yet.';

  @override
  String get likedPost => 'Liked post';

  @override
  String get postReferenceCopied => 'Post reference copied to clipboard.';

  @override
  String get noReportsFound => 'No reports found.';

  @override
  String get noRequestsFoundForFilter => 'No requests found for this filter.';

  @override
  String get createAnnouncement => 'Create Announcement';

  @override
  String get announcementPublishingSoon =>
      'Announcement publishing will be added next.';

  @override
  String get messageAction => 'Message';

  @override
  String get viewProfileAction => 'View profile';

  @override
  String get submit => 'Submit';

  @override
  String get notes => 'Notes';

  @override
  String get madeBy => 'Made by';

  @override
  String reportedUserIdLabel(Object id) {
    return 'Reported User ID: $id';
  }

  @override
  String reasonLabel(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String descriptionLabel(Object description) {
    return 'Description: $description';
  }

  @override
  String dateLabel(Object date) {
    return 'Date: $date';
  }

  @override
  String get noCommunitySelected => 'No community selected';

  @override
  String get microphonePermissionRequired =>
      'Microphone permission is required to record audio.';

  @override
  String get brainStormingTitle => 'Brain Storming';

  @override
  String get createNew => 'Create New';

  @override
  String get noBrainstormsYet => 'No Brainstorms yet';

  @override
  String get pollNotEnoughOptions =>
      'This poll does not have enough options to display.';

  @override
  String get voteBodyRequired => 'Vote body cannot be empty';

  @override
  String get voteBodyLabel => 'Vote body';

  @override
  String get atLeastTwoOptionsRequired => 'At least 2 options are required';

  @override
  String get thisOptionIsRequired => 'This option is required';

  @override
  String get pleaseFillAtLeastTwoOptions => 'Please fill at least 2 options';

  @override
  String get generalChatLabel => 'GENERAL CHAT';

  @override
  String get groupLabel => 'Group';

  @override
  String membersCountLabel(Object count) {
    return '$count members';
  }

  @override
  String get muteNotifications => 'Mute Notifications';

  @override
  String get addNewSuggestion => 'Add new suggestion';

  @override
  String get description => 'Description';

  @override
  String get reports => 'Reports';

  @override
  String get whatsapp => 'Whatsapp';

  @override
  String lastSeenTodayAt(Object time) {
    return 'Last Seen today at $time';
  }

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get apply => 'Apply';

  @override
  String get submitAction => 'Submit';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountMessage =>
      'Are you sure you want to delete your account? This will open your email app to request deletion.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get supportWhatsUnity => 'Support WhatsUnity';

  @override
  String get donationMessage =>
      'Your donations help keep our servers running and the app ad-free.';

  @override
  String get later => 'Later';

  @override
  String get donateNow => 'Donate Now';

  @override
  String get donateToCommunity => 'Donate to Community';

  @override
  String get logOut => 'Log Out';

  @override
  String get guest => 'Guest';

  @override
  String get accountSection => 'ACCOUNT';

  @override
  String get preferencesSection => 'PREFERENCES';

  @override
  String get supportLegalSection => 'SUPPORT & LEGAL';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get changePassword => 'Change Password';

  @override
  String get notifications => 'Notifications';

  @override
  String get appearance => 'Appearance';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get noCompoundSelected => 'No compound selected';

  @override
  String get submittedDocuments => 'Submitted Documents';

  @override
  String get cancelRegistration => 'Cancel Registration';

  @override
  String get joinCommunity => 'Join a Community';

  @override
  String get unknownState => 'Unknown State';

  @override
  String get userManagement => 'User Management';

  @override
  String get verificationRequests => 'Verification Requests';

  @override
  String get userReports => 'User Reports';

  @override
  String get call => 'Call';

  @override
  String get approve => 'Approve';

  @override
  String get decline => 'Decline';
}
