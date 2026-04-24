import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../network/CacheHelper.dart';

const String _kPermissionsWelcomeKey = 'app_permissions_welcome_completed_v1';

Future<bool> shouldShowPermissionsWelcome() async {
  final v = await CacheHelper.getData(key: _kPermissionsWelcomeKey, type: 'bool') as bool?;
  return v != true;
}

Future<void> markPermissionsWelcomeCompleted() async {
  await CacheHelper.saveData(key: _kPermissionsWelcomeKey, value: true);
}

bool _isRequestingPermissions = false;

/// Requests camera, photos, storage, microphone, and notification permissions.
/// Call only after the user explicitly opts in (e.g. welcome sheet).
Future<void> requestAppPermissions() async {
  if (_isRequestingPermissions) return;
  _isRequestingPermissions = true;
  try {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.microphone,
      Permission.notification,
    ].request();
  } finally {
    _isRequestingPermissions = false;
  }
}

/// One-time welcome dialog; permissions are requested only when the user taps Continue.
Future<void> showPermissionsWelcomeDialogIfNeeded(BuildContext context) async {
  final needed = await shouldShowPermissionsWelcome();
  if (!needed || !context.mounted) return;

  final theme = Theme.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        icon: Icon(Icons.privacy_tip_outlined, size: 40, color: theme.colorScheme.primary),
        title: const Text('Welcome'),
        content: const SingleChildScrollView(
          child: Text(
            'WhatsUnity works best with access to your camera, microphone, photos, and notifications '
            'so you can chat, share images, and get community updates.\n\n'
            'You can enable these in the next step, or skip and change them later in system settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;

  if (accepted == true) {
    await requestAppPermissions();
  }
  await markPermissionsWelcomeCompleted();
}
