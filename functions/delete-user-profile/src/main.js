const sdk = require("node-appwrite");

/**
 * Appwrite Cloud Function: delete-user-profile
 *
 * Trigger: users.*.delete
 *
 * Purpose:
 * When a user account is deleted from the Auth service, this function
 * deletes the corresponding document in the 'profiles' collection.
 * This deletion then triggers native database Cascades to clean up:
 * - user_roles
 * - user_apartments
 * - presence_sessions
 * - notification_preferences
 */
module.exports = async (context) => {
  const log = typeof context.log === "function" ? context.log : () => {};
  const errorLog = typeof context.error === "function" ? context.error : log;

  // 1. Resolve User ID from the event payload
  const eventPayload = context.req?.body || {};
  const userId = eventPayload.$id || eventPayload.userId || eventPayload.id;

  if (!userId) {
    log("No user ID found in event payload. Skipping.");
    return context.res.json({ ok: true, skipped: true, reason: "no_user_id" });
  }

  log(`Deleting profile for user: ${userId}`);

  // 2. Initialize Appwrite Client
  const endpoint = process.env.APPWRITE_FUNCTION_ENDPOINT || process.env.APPWRITE_ENDPOINT || "https://cloud.appwrite.io/v1";
  const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
  const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  const databaseId = process.env.APPWRITE_DATABASE_ID;

  if (!projectId || !apiKey || !databaseId) {
    errorLog("Missing required environment variables.");
    return context.res.json({ ok: false, error: "missing_config" }, 500);
  }

  const client = new sdk.Client()
    .setEndpoint(endpoint)
    .setProject(projectId)
    .setKey(apiKey);

  const databases = new sdk.Databases(client);

  // 3. Delete the profile document
  try {
    await databases.deleteDocument(databaseId, "profiles", userId);
    log(`Successfully deleted profile document: ${userId}`);

    return context.res.json({
      ok: true,
      userId,
      message: "Profile deleted, triggering cascades."
    });
  } catch (error) {
    if (error.code === 404) {
      log(`Profile document for user ${userId} not found. Nothing to delete.`);
      return context.res.json({ ok: true, message: "Profile already missing." });
    }

    errorLog(`Failed to delete profile: ${error.message}`);
    return context.res.json({ ok: false, error: "delete_failed", details: error.message }, 500);
  }
};
