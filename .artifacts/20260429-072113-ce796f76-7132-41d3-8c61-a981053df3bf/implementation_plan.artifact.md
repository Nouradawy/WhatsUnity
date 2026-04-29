# Code Review and Refactoring of `AuthRepositoryImpl`

This plan outlines the steps to analyze and refactor `AuthRepositoryImpl` to improve readability, maintainability, and adherence to project standards.

## User Review Required

- None at this stage. The specific refactoring opportunities will be presented after the initial analysis.

## Proposed Changes

### Analysis Phase (Completed)

I have analyzed `auth_repository_impl.dart` and identified several areas for improvement:
- **Long Methods**:
    - `completeRegistration` is a major violator of the "One-Job" rule, handling profile creation, role assignment, building/channel setup, and apartment registration.
    - `_provisioningMapFromSignUpData` contains complex loop-based logic and string manipulation that can be streamlined.
- **Naming Conventions**:
    - Some methods like `_checkExistingSession`, `fetchCurrentUser`, and `primeCurrentUser` could benefit from more consistent use of `remote`/`local` prefixes if they were interacting with different sources, but since they are in a Repository, we should ensure the *internal* calls to data sources follow this.
    - `_provisioningMapFromSignUpData` is quite wordy; something like `_mapSignUpDataToPrefs` might be cleaner.
- **Logic Simplification**:
    - The logic for creating/updating documents in `completeRegistration` has repetitive `try-catch` blocks for `AppwriteException (404)`. This can be abstracted into a helper method.
    - `_provisioningMapFromSignUpData` uses a nested helper function `strVal` which is good, but the overall structure of building the map is verbose.

### Refactoring Phase

#### `auth_repository_impl.dart`

- **Refactor `completeRegistration`**:
    - Extract logic for "Ensuring Profile Exists" into a private method.
    - Extract logic for "Handling User Roles" into a private method.
    - Extract logic for "Provisioning Building and Channel" into a private method.
    - Extract logic for "Registering User Apartment" into a private method.
- **Refactor `_provisioningMapFromSignUpData`**:
    - Streamline the key mapping process using a more declarative approach (e.g., iterating over a list of mappings).
- **Improve Naming and Documentation**:
    - Ensure all methods follow the verb-first naming convention.
    - Add/improve `///` docstrings.
- **Abstract Error Handling**:
    - Create a private helper for "Upsert Document" logic (handle 404 by creating) to reduce duplication in `updateProfile` and `completeRegistration`.

---

## Verification Plan

### Automated Tests
- I will check for existing unit tests for `AuthRepositoryImpl`.
- If none exist, I will attempt to create a simple test case to ensure the refactoring doesn't break core authentication flows (e.g., `signInWithPassword`, `signOut`).

### Manual Verification
- Verify that the `onAuthStateChange` stream still emits correctly after changes.
- Check if the `currentUser` property returns the expected value.
- Manually inspect the refactored code for adherence to the project's "One-Job" and naming rules.