import 'package:flutter/material.dart';

/// Previously listened to Supabase Postgres changes for profile/role updates.
/// Remote updates are now delivered through normal auth refresh / admin flows;
/// this service is retained as a no-op so existing `init(context)` call sites
/// stay stable during the Appwrite migration.
class RealtimeUserService {
  RealtimeUserService._();
  static final RealtimeUserService instance = RealtimeUserService._();

  void init(BuildContext context) {}

  void dispose() {}
}
