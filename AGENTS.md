# Role and Goal
You are an expert Flutter developer. You must strictly adhere to the following project conventions, architecture rules, and coding standards when generating, refactoring, or reviewing code for this project.

# 1. Project-Wide Naming Conventions
Logical naming is the foundation of readable code.

* **Data Sources:**
    * Functions interacting with `sqflite` MUST use the prefix `local` (e.g., `upsertLocalMessage`, `fetchLocalReports`).
    * Functions interacting with Appwrite MUST use the prefix `remote` (e.g., `createRemoteDocument`, `updateRemoteStatus`).
* **Actions:**
    * Use `fetch` for network/database retrieval.
    * Use `get` for simple property access or synchronous retrieval.
    * Use `sync` ONLY for functions within the `SyncEngine` that bridge local and remote states.
* **Variable Clarity:**
    * DO NOT use generic names like `data`, `item`, or `val`.
    * MUST use specific domain names: `messageMetadata`, `reportAttachment`, `syncJobPayload`.

# 2. Standardized Model Pattern (No "Weird" Mappers)
The project is strictly Appwrite-first. Eliminate intermediate translation layers. Models MUST map directly to the Appwrite collection attributes.

* **Flat Mapping:** Models MUST only use `fromAppwriteJson()` and `toAppwriteJson()`.
* **No Multi-Layer Translation:** If the data structure from Appwrite changes, update the model directly. Do not create a "mapper" class.
* **Sync Metadata Integration:** Every model MUST implement the `SyncMetadata` mixin to include `entity_version`, `sync_state`, and `local_updated_at` without cluttering the main business logic.
* **Type Strictness:** All IDs (compound, channel, message, user) MUST be handled as `String`. Do not use `int` for identifiers.

# 3. Implementation Guidelines for Refactoring
When executing "Cleanup and Refactor" requests, you MUST follow this specific order:

1. **Purge Legacy Keys:** Replace all `snake_case` keys that belonged to old Supabase tables with the standardized Appwrite keys defined in the schema.
2. **Consolidate Repository Logic:** Move complex "if-else" logic out of the UI/Cubits and into the `SyncRepository`. The Cubit should ONLY care about state (e.g., `Loading`, `Success`, `Syncing`).
3. **Audit the SyncEngine:** Ensure the `SyncEngine` is the only place where `mediaUploadService` and `RemoteDataSource` meet. The rest of the app MUST remain purely focused on local data.

# 4. Readability & Logic Standards
* **The "One-Job" Rule:** Every function MUST do exactly one thing. If a function you generate is longer than 30 lines, refactor it into smaller, logically named helper methods.
* **Verb-First Naming:** Functions MUST start with a strong action verb that describes the result: `validateUserSession`, `toggleMaintenanceStatus`, `calculateUnreadCount`.
* **Boolean Clarity:** Boolean variables and getters MUST start with `is`, `has`, or `should` (e.g., `isSyncing`, `hasAttachments`, `shouldRetry`).

# 5. Documentation & Comments (Human-First)
* **"Why, Not What":** DO NOT write comments that explain the code itself (e.g., `// Increment version`). Write comments that explain the intent (e.g., `// Incrementing version to ensure Last-Write-Wins (LWW) identifies this as the newest update`).
* **Header Documentation:** Every generated class and public method MUST have a `///` docstring explaining its role in the system.
* **Complex Logic:** Any "if-else" chain or complex Map manipulation MUST have an inline comment explaining the business logic behind the decision.

# 6. The "Mapper-Kill" Policy
* **Direct-to-Appwrite:** All models MUST use direct `fromAppwriteJson` and `toAppwriteJson` constructors that match the keys in `@APPWRITE_SCHEMA.md` exactly.
* **No Redundant Entities:** DO NOT create separate "Entity" and "Model" classes. The Model is the Entity. Transformation logic belongs inside the model's factory constructors, not in external "Mapper" classes.
* **String IDs Only:** All identification fields (e.g., `compoundId`, `channelId`) MUST be strictly typed as `String`. Never use `int` or `dynamic` for identifiers.