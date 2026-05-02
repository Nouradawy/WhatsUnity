# Role ID Enum Migration — Complete

**Date**: May 1, 2026  
**Status**: ✅ Code updated to use canonical enum names (no numeric fallbacks)

## Summary

The `user_roles.role_id` column has been converted from **numeric integers** (1 = user, 2 = manager, etc.) to **canonical enum names** (strings: "user", "manager", "admin", etc.) across:

1. **Appwrite backend** — enum column already provisioned
2. **Flutter app code** — all numeric conversions removed
3. **Local sqflite database** — stores as TEXT (string)
4. **Appwrite Functions** — on_user_register updated to handle enum names

## Mapping (exact)

| Numeric ID | Enum Name  |
| ---------- | ---------- |
| 1          | "user"     |
| 2          | "manager"  |
| 3          | "admin"    |
| 4          | "developer"|
| 5          | "owner"    |
| 6          | "tenant"   |

---

## Changes Made

### 1. **Appwrite Terraform (whatsunity-infra/main.tf)** ✅ Already present

```terraform
resource "appwrite_tablesdb_column" "user_roles_role_id" {
  database_id = "69e992170000e2f90e12"
  table_id    = "user_roles"
  key         = "role_id"
  type        = "enum"
  elements    = ["user", "manager", "admin", "developer", "owner", "tenant"]
  required    = true
}
```

### 2. **Local SQLite Database (lib/core/services/database_helper.dart)** ✅ Already TEXT

- Schema: `role_id TEXT` (not INTEGER)
- Migration `_migrateSessionsRoleIdToText` ensures existing data converted to TEXT

### 3. **Auth Repository (lib/features/auth/data/repositories/auth_repository_impl.dart)** ✅ Updated

#### Removed numeric conversions:
- ❌ `Roles.values[roleId - 1]` 
- ❌ `roleId.toString()` → numeric string
- ❌ `int.tryParse(roleId.toString())`
- ❌ Integer fallback handling

#### Updated methods:

**`_resolveRoleFromRoleId(dynamic roleRaw) → Roles?`**
- Now expects enum name string (e.g., "manager")
- Validates against `Roles.values.where((r) => r.name == t)`
- Returns `null` if invalid

**`_roleIdStringForRole(Roles role) → String`**
- Changed from `(index + 1).toString()` 
- Now simply returns `role.name`

**`_normalizeRoleIdString(dynamic roleRaw) → String?`**
- Accepts only valid enum names
- Returns canonical name or `null`
- Removed numeric parsing

**`processRegistration(…, roleId: String, …)`**
- Changed from `int roleId` to `String roleId`
- Validates and normalizes on entry
- Passes enum name to Appwrite

**`_remoteHandleUserRole(userId, roleName: String)`**
- Changed from `roleId: int`
- Writes directly to enum column
- No fallback for compatibility

**`_mapSignUpDataToPrefs(…)`**
- Reads role_id as string
- Calls `_normalizeRoleIdString` to validate
- Stores canonical name in prefs

### 4. **Auth Cubit (lib/features/auth/presentation/bloc/auth_cubit.dart)** ✅ Updated

**`submitRegistration(…, roleId: dynamic, …)`**
- Accepts `Roles` enum or string
- Converts to string if needed: `roleId is Roles ? roleId.name : roleId.toString()`
- Passes to repository as string

**`_resolveRoleFromRoleId(dynamic roleRaw) → Roles?`**
- Simplified: only validates enum names
- No numeric fallback

### 5. **Signup UI (lib/features/auth/presentation/widgets/signup_sections.dart)** ✅ Updated

**Google registration flow:**
```dart
// Before:
roleId: selectedRole.index + 1

// After:
roleId: selectedRole.name
```

### 6. **Appwrite Function (functions/on-user-register/lib/main.dart)** ✅ Updated

**Reading from prefs:**
```dart
// Before:
final roleId = _intPref(merged, const ['role_id', 'roleId']) ?? 1;

// After:
final roleId = _stringPref(merged, const ['role_id', 'roleId']) ?? 'user';
```

**Writing to Appwrite:**
```dart
Future<void> _createOrReplaceUserRole(
  Databases db,
  String databaseId,
  String userId,
  String roleName,  // <--- was int roleId
) async {
  final row = {
    'profile': userId,
    'user_id': userId,
    'role_id': roleName,  // <--- now string
    'version': 0,
  };
  // ...
}
```

Added helper:
```dart
String? _stringPref(Map<String, dynamic> m, List<String> keys) {
  return _s(m, keys);  // Returns string or null
}
```

---

## Data Migration Status

✅ **Manual data migration completed** (per user confirmation)
- All existing numeric `role_id` values in Appwrite `user_roles` table converted to enum names
- No further migration scripts needed

---

## Verification Checklist

- [x] Terraform provision: enum column defined
- [x] Local database: schema is TEXT
- [x] App code: no numeric `roleId` handling
- [x] Signup flows: send enum name string
- [x] Auth cubit: validate and normalize role_id on read
- [x] Appwrite function: accept and write enum names
- [x] Fallback code: removed (data is already canonical)

---

## Testing Steps

1. **New signup (standard email/password):**
   - User selects "manager" role
   - App sends: `role_id: "manager"` (enum name)
   - Appwrite stores as enum value in `user_roles.role_id`

2. **Google sign-up:**
   - User completes Google OAuth
   - Selects role (e.g., "admin")
   - App calls `submitRegistration(roleId: "admin")`
   - Function `on_user_register` reads `_stringPref(..., role_id)` → "admin"
   - Writes to Appwrite: `role_id: "admin"`

3. **Local session restore:**
   - SQLite `sessions.role_id` is TEXT: "manager"
   - App reads and validates via `_resolveRoleFromRoleId("manager")` → `Roles.manager`

4. **Realtime role changes:**
   - User's role updated in `user_roles` collection
   - Payload contains `role_id: "admin"` (string)
   - App resolves to `Roles.admin` enum

---

## Breaking Changes (None for users)

- ✅ **Data**: Already migrated to enum names
- ✅ **API**: No breaking public API changes (internal normalization)
- ✅ **Compatibility**: All numeric handling removed (safe after data migration)

---

## Files Modified

| File | Change |
| ---- | ------ |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Removed numeric conversions; methods now expect/return enum names |
| `lib/features/auth/presentation/bloc/auth_cubit.dart` | Updated `submitRegistration` and `_resolveRoleFromRoleId` |
| `lib/features/auth/presentation/widgets/signup_sections.dart` | Sign-up sends `selectedRole.name` instead of index+1 |
| `functions/on-user-register/lib/main.dart` | Read `role_id` as string; write enum name to Appwrite |

---

## Future Work

- (Optional) Add test cases for role resolution to ensure enum validation
- (Optional) Monitor logs for any "invalid role" errors during next release

---

## Rollback (if needed — not recommended)

To revert to numeric schema:
1. Export current `user_roles` table
2. Convert all enum names back to numeric IDs
3. Alter Appwrite column from enum to integer
4. Restore numeric handling in app code

**However**, since data is now canonical (enum names), it's better to keep the new schema and just fix any code issues.

---

## Questions?

Refer to:
- `APPWRITE_SCHEMA.md` — full Appwrite schema
- `MIGRATION_PLAN.md` — broader migration context
- `whatsunity-infra/main.tf` — infrastructure as code

