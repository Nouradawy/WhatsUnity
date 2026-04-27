import 'package:flutter/material.dart';

import '../widgets/prototype_scaffold.dart';

class UiUxPrototypeCatalogPage extends StatefulWidget {
  const UiUxPrototypeCatalogPage({super.key});

  @override
  State<UiUxPrototypeCatalogPage> createState() =>
      _UiUxPrototypeCatalogPageState();
}

class _UiUxPrototypeCatalogPageState extends State<UiUxPrototypeCatalogPage> {
  PrototypeViewState _selectedState = PrototypeViewState.defaultState;
  String _selectedGroup = 'All';

  static const List<ScreenPrototypeDefinition> _definitions = [
    ScreenPrototypeDefinition(
      featureGroup: 'Auth',
      screenName: 'Sign In / Sign Up',
      screenGoal: 'Authenticate and route user to the correct experience.',
      primaryActionLabel: 'Continue',
      entryPoint: 'App launch',
      exitPoint: 'Main shell',
      transitionNote: 'Default -> Loading -> Success/Error',
      placeholders: ['Email field', 'Password field', 'Mode toggle'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Auth',
      screenName: 'OTP Verification',
      screenGoal: 'Confirm account via one-time code.',
      primaryActionLabel: 'Verify',
      entryPoint: 'Sign up success',
      exitPoint: 'Main shell',
      transitionNote: 'Code submit -> verify -> success/error',
      placeholders: ['OTP boxes', 'Resend action', 'Timer feedback'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Auth',
      screenName: 'Join Community',
      screenGoal: 'Select community before account completion.',
      primaryActionLabel: 'Join',
      entryPoint: 'Auth onboarding',
      exitPoint: 'Role selection',
      transitionNote: 'List load -> selection -> confirmation',
      placeholders: ['Search bar', 'Community list', 'Selection state'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Auth',
      screenName: 'Role Selection',
      screenGoal: 'Collect role-specific onboarding requirements.',
      primaryActionLabel: 'Confirm role',
      entryPoint: 'Auth form progression',
      exitPoint: 'Registration submit',
      transitionNote: 'Role change -> form variant update',
      placeholders: ['Role chips', 'Role-specific fields', 'Validation hint'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Home',
      screenName: 'Main Shell / Bottom Nav',
      screenGoal: 'Provide role-based tab navigation.',
      primaryActionLabel: 'Switch tab',
      entryPoint: 'Post-auth',
      exitPoint: 'Feature tabs',
      transitionNote: 'Tab change updates active content',
      placeholders: ['Top app bar', 'Tab content area', 'Bottom nav items'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Home',
      screenName: 'Resident Home',
      screenGoal: 'Surface day-to-day services and updates.',
      primaryActionLabel: 'Open service',
      entryPoint: 'Main shell',
      exitPoint: 'Service flow',
      transitionNote: 'Card tap -> detail flow',
      placeholders: ['Greeting header', 'Service cards', 'Community highlights'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Home',
      screenName: 'Manager Home',
      screenGoal: 'Give operational overview and quick actions.',
      primaryActionLabel: 'Manage announcements',
      entryPoint: 'Main shell',
      exitPoint: 'Announcement management',
      transitionNote: 'Card tap -> action panel',
      placeholders: ['KPI summary', 'Action shortcuts', 'Announcement panel'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Home',
      screenName: 'Announcement Screen',
      screenGoal: 'Present announcements with clear reading state.',
      primaryActionLabel: 'Open announcement',
      entryPoint: 'Home entry points',
      exitPoint: 'Announcement detail',
      transitionNote: 'List item tap -> detail',
      placeholders: ['Announcement list', 'Priority badge', 'Read marker'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Chat',
      screenName: 'Building Chat Container',
      screenGoal: 'Access conversations and active thread.',
      primaryActionLabel: 'Open chat',
      entryPoint: 'Main shell',
      exitPoint: 'Thread screen',
      transitionNote: 'Conversation select -> thread',
      placeholders: ['Conversation list', 'Unread badges', 'Pinned thread'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Chat',
      screenName: 'Chat Thread',
      screenGoal: 'Read and send messages safely.',
      primaryActionLabel: 'Send message',
      entryPoint: 'Conversation list',
      exitPoint: 'Thread persists',
      transitionNote: 'Composer submit -> pending -> delivered/error',
      placeholders: ['Message timeline', 'Composer', 'Reply context bar'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Chat',
      screenName: 'Message Actions Popover',
      screenGoal: 'Expose actions for a specific message/member.',
      primaryActionLabel: 'View profile',
      entryPoint: 'Long press message',
      exitPoint: 'Profile or direct action',
      transitionNote: 'Open menu -> pick action -> success/error',
      placeholders: ['Action list', 'Destructive confirm', 'Action feedback'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Chat',
      screenName: 'Member Details',
      screenGoal: 'Inspect member profile and available contact actions.',
      primaryActionLabel: 'Open profile',
      entryPoint: 'Thread header or action popover',
      exitPoint: 'Profile or chat action',
      transitionNote: 'Member tap -> details -> action',
      placeholders: ['Member card', 'Role badge', 'Available actions'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Profile',
      screenName: 'Profile Overview',
      screenGoal: 'Show user identity and account controls.',
      primaryActionLabel: 'Edit profile',
      entryPoint: 'Main shell',
      exitPoint: 'Edit flow',
      transitionNote: 'Overview -> edit -> save',
      placeholders: ['Avatar header', 'Account fields', 'Security actions'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Profile',
      screenName: 'Edit Profile',
      screenGoal: 'Update personal details with clear validation.',
      primaryActionLabel: 'Save changes',
      entryPoint: 'Profile overview',
      exitPoint: 'Profile overview',
      transitionNote: 'Edit -> save -> success/error',
      placeholders: ['Editable fields', 'Validation errors', 'Save footer'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Maintenance',
      screenName: 'Requests List',
      screenGoal: 'Track maintenance requests by status.',
      primaryActionLabel: 'Create request',
      entryPoint: 'Main shell',
      exitPoint: 'Request form',
      transitionNote: 'List filter -> detail/create',
      placeholders: ['Filter chips', 'Request cards', 'Status indicator'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Maintenance',
      screenName: 'Request Form',
      screenGoal: 'Submit actionable maintenance request.',
      primaryActionLabel: 'Submit request',
      entryPoint: 'Requests list',
      exitPoint: 'Request confirmation',
      transitionNote: 'Validate -> submit -> success/error',
      placeholders: ['Category selector', 'Description field', 'Attachment row'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Maintenance',
      screenName: 'Request Detail / Timeline',
      screenGoal: 'Show request lifecycle and updates.',
      primaryActionLabel: 'Add update',
      entryPoint: 'Requests list',
      exitPoint: 'Requests list',
      transitionNote: 'Open detail -> timeline progression',
      placeholders: ['Timeline nodes', 'Assigned staff info', 'Status summary'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Social',
      screenName: 'Social Feed',
      screenGoal: 'Consume and engage with community posts.',
      primaryActionLabel: 'Create post',
      entryPoint: 'Main shell',
      exitPoint: 'Post creation',
      transitionNote: 'Feed load -> actions -> post detail',
      placeholders: ['Composer shortcut', 'Post cards', 'Interaction row'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Social',
      screenName: 'Post Interactions',
      screenGoal: 'Like, comment, and share with clear feedback.',
      primaryActionLabel: 'Comment',
      entryPoint: 'Post card',
      exitPoint: 'Comment dialog',
      transitionNote: 'Action tap -> optimistic update -> settle',
      placeholders: ['Like action', 'Comment action', 'Share action'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Social',
      screenName: 'Post Detail / Comments',
      screenGoal: 'Read thread context and contribute comments.',
      primaryActionLabel: 'Post comment',
      entryPoint: 'Feed interaction',
      exitPoint: 'Feed',
      transitionNote: 'Open detail -> submit comment -> feedback',
      placeholders: ['Post header', 'Comment list', 'Comment composer'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Social',
      screenName: 'Create Post',
      screenGoal: 'Compose a post with clear privacy and media affordances.',
      primaryActionLabel: 'Publish post',
      entryPoint: 'Feed create shortcut',
      exitPoint: 'Feed',
      transitionNote: 'Draft -> validate -> publish',
      placeholders: ['Text composer', 'Media picker', 'Audience selection'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Admin',
      screenName: 'Admin Dashboard Shell',
      screenGoal: 'Provide operational command center.',
      primaryActionLabel: 'Open reports',
      entryPoint: 'Admin tab',
      exitPoint: 'Members/Reports modules',
      transitionNote: 'Tile select -> module view',
      placeholders: ['Overview metrics', 'Module shortcuts', 'Recent activity'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Admin',
      screenName: 'Reports List',
      screenGoal: 'Review and triage submitted reports.',
      primaryActionLabel: 'Resolve report',
      entryPoint: 'Admin dashboard',
      exitPoint: 'Report detail',
      transitionNote: 'List -> detail -> action outcome',
      placeholders: ['Severity chip', 'Reporter details', 'Action menu'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Admin',
      screenName: 'Members Management',
      screenGoal: 'Search and manage members with role-sensitive actions.',
      primaryActionLabel: 'Open member',
      entryPoint: 'Admin dashboard',
      exitPoint: 'Member detail',
      transitionNote: 'Search -> list -> action',
      placeholders: ['Search input', 'Member rows', 'Role/action controls'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Admin',
      screenName: 'Report Detail',
      screenGoal: 'Resolve report with accountable moderation decisions.',
      primaryActionLabel: 'Apply resolution',
      entryPoint: 'Reports list',
      exitPoint: 'Reports list',
      transitionNote: 'Open report -> decision -> confirmation',
      placeholders: ['Incident context', 'Evidence section', 'Resolution actions'],
    ),
    ScreenPrototypeDefinition(
      featureGroup: 'Manager',
      screenName: 'Announcement Management',
      screenGoal: 'Publish and manage community announcements.',
      primaryActionLabel: 'Publish announcement',
      entryPoint: 'Manager home',
      exitPoint: 'Announcement timeline',
      transitionNote: 'Draft -> publish -> visible state',
      placeholders: ['Draft form', 'Audience selector', 'Published list'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final groups = <String>{
      'All',
      ..._definitions.map((definition) => definition.featureGroup),
    }.toList();

    final filtered = _selectedGroup == 'All'
        ? _definitions
        : _definitions
            .where((definition) => definition.featureGroup == _selectedGroup)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI/UX Prototype Catalog'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mid-fidelity prototypes for core and admin/manager flows.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in groups)
                ChoiceChip(
                  label: Text(group),
                  selected: _selectedGroup == group,
                  onSelected: (_) => setState(() => _selectedGroup = group),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<PrototypeViewState>(
            segments: const [
              ButtonSegment(
                value: PrototypeViewState.defaultState,
                label: Text('Default'),
              ),
              ButtonSegment(
                value: PrototypeViewState.loading,
                label: Text('Loading'),
              ),
              ButtonSegment(
                value: PrototypeViewState.empty,
                label: Text('Empty'),
              ),
              ButtonSegment(
                value: PrototypeViewState.error,
                label: Text('Error'),
              ),
            ],
            selected: {_selectedState},
            onSelectionChanged: (selection) {
              setState(() => _selectedState = selection.first);
            },
          ),
          const SizedBox(height: 16),
          for (final definition in filtered)
            PrototypeScreenCard(
              definition: definition,
              viewState: _selectedState,
            ),
        ],
      ),
    );
  }
}
