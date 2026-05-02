import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/services/message_notification_lifecycle_service.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/constants/Constants.dart';
import '../../../../core/services/PolicyDialog.dart';
import '../../../../core/services/browser_notification_bridge.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/otp_screen.dart';
import '../bloc/profile_cubit.dart';
import '../bloc/profile_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController userNameController;
  late final TextEditingController fullNameController;
  late final TextEditingController emailController;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  bool _controllersInitialized = false;
  bool _isNotificationSettingsLoading = false;
  bool _isGeneralChatNotificationsEnabled = true;
  bool _isBuildingChatNotificationsEnabled = true;
  bool _isAdminNotificationsEnabled = true;
  bool _isMaintenanceNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    userNameController = TextEditingController();
    fullNameController = TextEditingController();
    emailController = TextEditingController();
  }

  @override
  void dispose() {
    userNameController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _initializeControllers(Authenticated state) {
    if (!_controllersInitialized) {
      userNameController.text = state.currentUser?.displayName ?? "";
      fullNameController.text = state.currentUser?.fullName ?? "";
      emailController.text = state.user.email ?? "";
      _controllersInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNotificationPreferences(state.user.id);
      });
    }
  }

  Future<void> _loadNotificationPreferences(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _isNotificationSettingsLoading = true;
    });
    final notificationService = AppServices.messageNotificationLifecycleService;
    final generalChatEnabled = await notificationService
        .fetchIsNotificationChannelEnabled(
          userId: normalizedUserId,
          notificationPreferenceChannel: NotificationPreferenceChannel.generalChat,
        );
    final buildingChatEnabled = await notificationService
        .fetchIsNotificationChannelEnabled(
          userId: normalizedUserId,
          notificationPreferenceChannel: NotificationPreferenceChannel.buildingChat,
        );
    final adminNotificationsEnabled = await notificationService
        .fetchIsNotificationChannelEnabled(
          userId: normalizedUserId,
          notificationPreferenceChannel: NotificationPreferenceChannel.adminNotification,
        );
    final maintenanceNotificationsEnabled = await notificationService
        .fetchIsNotificationChannelEnabled(
          userId: normalizedUserId,
          notificationPreferenceChannel: NotificationPreferenceChannel.maintenanceNotification,
        );
    if (!mounted) return;
    setState(() {
      _isGeneralChatNotificationsEnabled = generalChatEnabled;
      _isBuildingChatNotificationsEnabled = buildingChatEnabled;
      _isAdminNotificationsEnabled = adminNotificationsEnabled;
      _isMaintenanceNotificationsEnabled = maintenanceNotificationsEnabled;
      _isNotificationSettingsLoading = false;
    });
  }

  Future<void> _toggleNotificationPreference({
    required String userId,
    required NotificationPreferenceChannel notificationPreferenceChannel,
    required bool isEnabled,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;
    await AppServices.messageNotificationLifecycleService
        .updateNotificationChannelEnabled(
          userId: normalizedUserId,
          notificationPreferenceChannel: notificationPreferenceChannel,
          isEnabled: isEnabled,
        );
    if (!mounted) return;
    setState(() {
      if (notificationPreferenceChannel ==
          NotificationPreferenceChannel.generalChat) {
        _isGeneralChatNotificationsEnabled = isEnabled;
      } else if (notificationPreferenceChannel ==
          NotificationPreferenceChannel.buildingChat) {
        _isBuildingChatNotificationsEnabled = isEnabled;
      } else if (notificationPreferenceChannel ==
          NotificationPreferenceChannel.adminNotification) {
        _isAdminNotificationsEnabled = isEnabled;
      } else {
        _isMaintenanceNotificationsEnabled = isEnabled;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        if (authState is Authenticated) {
          _initializeControllers(authState);

          final body = SingleChildScrollView(
              child: Container(
                color: HexColor("#f9f9f9"),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeader(authState),
                    _buildInfo(authState),
                    const SizedBox(height: 20),
                    _buildSections(context, authState),
                    const SizedBox(height: 10),
                    _buildFooterActions(context, authState),
                  ],
                ),
              ),
            );

          if (context.isIOS) {
            return CupertinoPageScaffold(
              backgroundColor: HexColor("#f9f9f9"),
              navigationBar: CupertinoNavigationBar(
                backgroundColor: Colors.white,
                middle: Text(
                  context.loc.profile,
                  style: GoogleFonts.plusJakartaSans(),
                ),
              ),
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: body,
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: Text(
                context.loc.profile,
                style: GoogleFonts.plusJakartaSans(),
              ),
            ),
            body: body,
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
      },
    );
  }

  Widget _buildHeader(Authenticated state) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      alignment: AlignmentDirectional.center,
      child: Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          const Icon(Icons.edit),
          CircleAvatar(
            radius: 60,
            backgroundImage:
                state.currentUser?.avatarUrl != null
                    ? CachedNetworkImageProvider(
                      state.currentUser!.avatarUrl.toString(),
                    )
                    : const AssetImage("assets/defaultUser.webp")
                        as ImageProvider,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(Authenticated state) {
    return Column(
      children: [
        Text(
          state.currentUser?.displayName ?? context.loc.guest,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        if (state.currentUser != null)
          Text(
            'Building ${state.currentUser?.building} • Apartment ${state.currentUser?.apartment}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: HexColor("#637488"),
            ),
          ),
      ],
    );
  }

  Widget _buildSections(BuildContext context, Authenticated authState) {
    final account = [context.loc.editProfile, context.loc.changePassword];
    final preferences = [context.loc.notifications, context.loc.appearance];
    final support = [
      context.loc.helpCenter,
      context.loc.privacyPolicy,
      context.loc.termsOfUse,
      context.loc.deleteAccountTitle,
    ];
    return Column(
      children: [
        _buildWebNotificationStatus(context, authState),
        _buildSectionGroup(
          context,
          authState,
          title: context.loc.accountSection,
          items: account,
          section: ProfileSection.account,
          googleFilter: true,
        ),
        const SizedBox(height: 15),
        _buildSectionGroup(
          context,
          authState,
          title: context.loc.preferencesSection,
          items: preferences,
          section: ProfileSection.preferences,
        ),
        const SizedBox(height: 15),
        _buildSectionGroup(
          context,
          authState,
          title: context.loc.supportLegalSection,
          items: support,
          section: ProfileSection.support,
        ),
      ],
    );
  }

  Widget _buildWebNotificationStatus(BuildContext context, Authenticated state) {
    if (!kIsWeb) return const SizedBox.shrink();

    final bridge = createBrowserNotificationBridge();
    final permission = bridge.getPermissionStatus();
    final isStandalone = bridge.isStandalone();
    final isApple = bridge.isAppleWeb();

    Color statusColor = Colors.orange;
    String statusText = 'Notifications not configured';
    String? tip;

    if (permission == 'granted') {
      if (isApple && !isStandalone) {
        statusColor = Colors.orange;
        statusText = 'Notifications enabled (but limited)';
        tip = 'Add to Home Screen to receive notifications while app is closed.';
      } else {
        statusColor = Colors.green;
        statusText = 'Notifications enabled';
      }
    } else if (permission == 'denied') {
      statusColor = Colors.red;
      statusText = 'Notifications blocked';
      tip = 'Please enable notifications in your browser settings.';
    } else if (permission == 'default') {
      statusText = 'Notifications not requested';
      tip = 'Tap "Apply" in Edit Profile or visit the welcome screen to enable.';
    } else if (permission == 'unsupported') {
      statusColor = Colors.grey;
      statusText = 'Notifications not supported';
      if (isApple && !isStandalone) {
        statusColor = Colors.orange;
        statusText = 'Action Required';
        tip = 'Tap "Share" -> "Add to Home Screen" to enable background notifications on iOS/iPadOS.';
      } else {
        tip = 'Your browser does not support web notifications.';
      }
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Web Notification Status',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: statusColor,
            ),
          ),
          if (tip != null) ...[
            const SizedBox(height: 8),
            Text(
              tip,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionGroup(
    BuildContext context,
    Authenticated authState, {
    required String title,
    required List items,
    required ProfileSection section,
    bool googleFilter = false,
  }) {
    final isGoogle = authState.user.userMetadata?["provider"] == "google";
    final count = (googleFilter && isGoogle) ? 1 : items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10.0, bottom: 8),
          child: Text(title, style: context.txt.profileListHead),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children:
                items.sublist(0, count).asMap().entries.map((entry) {
                  int index = entry.key;
                  var value = entry.value;
                  return _buildAccordionItem(
                    context,
                    authState,
                    section,
                    index,
                    value,
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccordionItem(
    BuildContext context,
    Authenticated authState,
    ProfileSection section,
    int index,
    String title,
  ) {
    int totalForSection(ProfileSection profileSection) {
      switch (profileSection) {
        case ProfileSection.account:
          return 2;
        case ProfileSection.preferences:
          return 2;
        case ProfileSection.support:
          return 4;
      }
    }

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profileState) {
        final profileCubit = context.read<ProfileCubit>();
        final isActive = profileCubit.isSectionActive(section, index);

        return AnimatedCrossFade(
          key: ValueKey('${section.name}_item_$index'),
          crossFadeState:
              isActive ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 500),
          firstChild: InkWell(
            onTap: () => _handleItemTap(context, authState, section, index),
            child: _buildItemLabel(title, index, totalForSection(section)),
          ),
          secondChild: Column(
            children: [
              InkWell(
                onTap: () => profileCubit.toggleSection(section, index),
                child: _buildItemLabel(title, index, totalForSection(section)),
              ),
              _buildExpandedContent(context, authState, section, index),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemLabel(String title, int index, int total) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w400,
                  fontSize: 15,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
        if (index < total - 1) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }

  void _handleItemTap(
    BuildContext context,
    Authenticated authState,
    ProfileSection section,
    int index,
  ) {
    if (section == ProfileSection.support) {
      if (index == 1) {
        _showPolicy(context, 'Privacy_policy');
        return;
      } else if (index == 2) {
        _showPolicy(context, 'Terms_conditions');
        return;
      } else if (index == 3) {
        _showDeleteAccountDialog(context, authState);
        return;
      }
    }
    context.read<ProfileCubit>().toggleSection(section, index);
  }

  Widget _buildExpandedContent(
    BuildContext context,
    Authenticated authState,
    ProfileSection section,
    int index,
  ) {
    if (section == ProfileSection.account) {
      if (index == 0) return _buildEditProfileForm(context, authState);
      if (index == 1) return _buildChangePasswordForm(context);
    }
    if (section == ProfileSection.preferences && index == 0) {
      return _buildNotificationChannelSettings(context, authState);
    }
    return const SizedBox.shrink();
  }

  Widget _buildNotificationChannelSettings(
    BuildContext context,
    Authenticated authState,
  ) {
    if (_isNotificationSettingsLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          _buildNotificationChannelSwitchTile(
            title: 'GeneralChat',
            subtitle: 'Mentions and new messages from GeneralChat.',
            value: _isGeneralChatNotificationsEnabled,
            onChanged:
                (isEnabled) => _toggleNotificationPreference(
                  userId: authState.user.id,
                  notificationPreferenceChannel:
                      NotificationPreferenceChannel.generalChat,
                  isEnabled: isEnabled,
                ),
          ),
          _buildNotificationChannelSwitchTile(
            title: 'BuildingChat',
            subtitle: 'Updates from your building chat channel.',
            value: _isBuildingChatNotificationsEnabled,
            onChanged:
                (isEnabled) => _toggleNotificationPreference(
                  userId: authState.user.id,
                  notificationPreferenceChannel:
                      NotificationPreferenceChannel.buildingChat,
                  isEnabled: isEnabled,
                ),
          ),
          _buildNotificationChannelSwitchTile(
            title: 'Admin',
            subtitle: 'Administrative announcements and alerts.',
            value: _isAdminNotificationsEnabled,
            onChanged:
                (isEnabled) => _toggleNotificationPreference(
                  userId: authState.user.id,
                  notificationPreferenceChannel:
                      NotificationPreferenceChannel.adminNotification,
                  isEnabled: isEnabled,
                ),
          ),
          _buildNotificationChannelSwitchTile(
            title: 'Maintenance',
            subtitle: 'Maintenance updates and service notices.',
            value: _isMaintenanceNotificationsEnabled,
            onChanged:
                (isEnabled) => _toggleNotificationPreference(
                  userId: authState.user.id,
                  notificationPreferenceChannel:
                      NotificationPreferenceChannel.maintenanceNotification,
                  isEnabled: isEnabled,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationChannelSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w400,
          fontSize: 12,
          color: HexColor("#637488"),
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildEditProfileForm(BuildContext context, Authenticated authState) {
    final profileCubit = context.read<ProfileCubit>();
    if (profileCubit.isOtpVisible) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.36,
        child: OtpScreen(email: emailController.text, isProfile: true),
      );
    }

    return Form(
      key: _formKey1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            defaultTextForm(
              context,
              controller: fullNameController,
              keyboardType: TextInputType.name,
              labelText: context.loc.fullName,
            ),
            const SizedBox(height: 10),
            defaultTextForm(
              context,
              controller: userNameController,
              keyboardType: TextInputType.name,
              labelText: context.loc.displayName,
            ),
            if (authState.user.userMetadata?["provider"] != "google") ...[
              const SizedBox(height: 10),
              defaultTextForm(
                context,
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                labelText: context.loc.emailAddress,
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: MaterialButton(
                onPressed: () => _applyProfileChanges(context, authState),
                color: Colors.indigoAccent.shade200,
                textColor: Colors.white,
                child: Text(context.loc.apply),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordForm(BuildContext context) {
    return Form(
      key: _formKey2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            defaultTextForm(
              context,
              controller: passwordController,
              IsPassword: true,
              labelText: context.loc.password,
              keyboardType: TextInputType.visiblePassword,
            ),
            const SizedBox(height: 10),
            defaultTextForm(
              context,
              controller: confirmPasswordController,
              IsPassword: true,
              labelText: context.loc.confirmPassword,
              keyboardType: TextInputType.visiblePassword,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: MaterialButton(
                onPressed: () => _updatePassword(context),
                color: Colors.indigoAccent.shade200,
                textColor: Colors.white,
                child: Text(context.loc.submitAction),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _applyProfileChanges(
    BuildContext context,
    Authenticated authState,
  ) async {
    if (!(_formKey1.currentState?.validate() ?? false)) return;

    final authCubit = context.read<AuthCubit>();
    final profileCubit = context.read<ProfileCubit>();
    final currentUser = authState.currentUser;

    if (userNameController.text != currentUser?.displayName ||
        fullNameController.text != currentUser?.fullName) {
      await authCubit.updateProfile(
        fullName: fullNameController.text,
        displayName: userNameController.text,
        ownerType: currentUser!.ownerType!,
        phoneNumber: currentUser.phoneNumber,
      );
    }

    if (emailController.text != authState.user.email) {
      await authCubit.requestEmailChange(emailController.text);
      profileCubit.setOtpVisibility(true);
    }
  }

  Future<void> _updatePassword(BuildContext context) async {
    if (!(_formKey2.currentState?.validate() ?? false)) return;
    if (passwordController.text != confirmPasswordController.text) return;

    await context.read<AuthCubit>().updatePassword(passwordController.text);
  }

  Widget _buildFooterActions(BuildContext context, Authenticated authState) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.8,
      child: Column(
        children: [
          MaterialButton(
            onPressed: () => _showDonationDialog(context),
            color: Colors.pinkAccent,
            height: 42,
            minWidth: double.infinity,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.handHoldingHeart,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  context.loc.donateToCommunity,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MaterialButton(
            onPressed: () => context.read<AuthCubit>().signOut(),
            color: Colors.blueGrey.shade100,
            height: 42,
            minWidth: double.infinity,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.arrowRightFromBracket,
                  color: HexColor("#ae060e"),
                  size: 16,
                ),
                const SizedBox(width: 10),
                Text(
                  context.loc.logOut,
                  style: GoogleFonts.plusJakartaSans(
                    color: HexColor("#ae060e"),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showPolicy(BuildContext context, String baseName) {
    showDialog(
      context: context,
      builder: (context) {
        final locale = Localizations.localeOf(context).languageCode;
        final fileName = locale == "ar" ? "${baseName}_ar.md" : "$baseName.md";
        return Dialog(child: PolicyDialog(mdFileName: fileName));
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context, Authenticated authState) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.loc.deleteAccountTitle),
            content: Text(context.loc.deleteAccountMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.loc.cancel),
              ),
              TextButton(
                onPressed: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'support@whatsunity.work.gd',
                    query:
                        'subject=Delete My Account&body=User ID: ${authState.user.id}',
                  );
                  await launchUrl(emailLaunchUri);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: Text(
                  context.loc.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showDonationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.loc.supportWhatsUnity),
            content: Text(context.loc.donationMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.loc.later),
              ),
              TextButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse("https://ipn.eg/S/nouradawynbe/instapay/673PPO"),
                    mode: LaunchMode.externalApplication,
                  );
                  Navigator.pop(context);
                },
                child: Text(context.loc.donateNow),
              ),
            ],
          ),
    );
  }
}
