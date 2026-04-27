const sdk = require("node-appwrite");

const COLLECTION_MESSAGES = "messages";
const COLLECTION_CHANNELS = "channels";
const COLLECTION_BUILDINGS = "buildings";
const COLLECTION_USER_APARTMENTS = "user_apartments";

function parseBody(raw) {
  if (raw == null || raw === "") return {};
  if (typeof raw === "object" && !Array.isArray(raw)) return raw;
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw);
      return typeof parsed === "object" && parsed !== null ? parsed : {};
    } catch {
      return {};
    }
  }
  return {};
}

function truncateText(value, max = 120) {
  const text = String(value ?? "").trim();
  if (!text) return "";
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function resolveNotificationProfile(channelType) {
  if (channelType === "BUILDING_CHAT") {
    return {
      notificationTitle: "Building chat",
      notificationFallbackBody: "You received a new building message.",
      notificationChannel: "BuildingChat",
    };
  }
  if (channelType === "ADMIN_NOTIFICATION") {
    return {
      notificationTitle: "Admin notification",
      notificationFallbackBody: "You received an admin notification.",
      notificationChannel: "Admin",
    };
  }
  if (channelType === "MAINTENANCE_NOTIFICATION") {
    return {
      notificationTitle: "Maintenance notification",
      notificationFallbackBody: "You received a maintenance update.",
      notificationChannel: "Maintenance",
    };
  }
  return {
    notificationTitle: "General chat",
    notificationFallbackBody: "You received a new message.",
    notificationChannel: "GeneralChat",
  };
}

function extractRowFromEventPayload(body) {
  if (body && typeof body === "object" && body.$id && body.channel_id) {
    return body;
  }
  if (body && typeof body === "object" && body.payload && typeof body.payload === "object") {
    const payload = body.payload;
    if (payload.$id && payload.channel_id) return payload;
  }
  if (body && typeof body === "object" && body.data && typeof body.data === "object") {
    const data = body.data;
    if (data.$id && data.channel_id) return data;
  }
  return null;
}

function isTrustedEventInvocation(context) {
  const headers = context.req?.headers ?? {};
  const eventHeader =
    headers["x-appwrite-event"] ||
    headers["X-Appwrite-Event"] ||
    headers["x-appwrite-events"] ||
    headers["X-Appwrite-Events"];
  if (!eventHeader) return false;
  const normalized = String(eventHeader);
  return normalized.includes("databases.") && normalized.includes(".messages.") && normalized.includes(".create");
}

function resolveClientConfig() {
  const endpoint = process.env.APPWRITE_FUNCTION_ENDPOINT || process.env.APPWRITE_ENDPOINT;
  const projectId =
    process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
  const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  const databaseId = process.env.APPWRITE_DATABASE_ID;
  if (!endpoint || !projectId || !apiKey || !databaseId) {
    throw new Error(
      "Missing required env vars: APPWRITE_ENDPOINT/APPWRITE_FUNCTION_ENDPOINT, APPWRITE_PROJECT_ID/APPWRITE_FUNCTION_PROJECT_ID, APPWRITE_API_KEY/APPWRITE_FUNCTION_API_KEY, APPWRITE_DATABASE_ID."
    );
  }
  return { endpoint, projectId, apiKey, databaseId };
}

async function listAllUserApartments(databases, databaseId, queries) {
  const rows = [];
  let offset = 0;
  const pageSize = 100;
  while (true) {
    const page = await databases.listDocuments(
      databaseId,
      COLLECTION_USER_APARTMENTS,
      [...queries, sdk.Query.limit(pageSize), sdk.Query.offset(offset)]
    );
    rows.push(...page.documents);
    if (page.documents.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

async function resolveRecipientUserIds(databases, databaseId, channelDoc) {
  const compoundId = String(channelDoc.compound_id ?? "").trim();
  const channelType = String(channelDoc.type ?? "").trim();
  if (!compoundId || !channelType) return [];

  if (channelType === "COMPOUND_GENERAL") {
    const rows = await listAllUserApartments(databases, databaseId, [
      sdk.Query.equal("compound_id", compoundId),
      sdk.Query.isNull("deleted_at"),
    ]);
    return rows.map((row) => String(row.user_id ?? "").trim()).filter(Boolean);
  }

  if (channelType === "BUILDING_CHAT") {
    const buildingDocId = String(channelDoc.building_id ?? "").trim();
    if (!buildingDocId) return [];
    const building = await databases.getDocument(
      databaseId,
      COLLECTION_BUILDINGS,
      buildingDocId
    );
    const buildingName = String(building.building_name ?? "").trim();
    if (!buildingName) return [];
    const rows = await listAllUserApartments(databases, databaseId, [
      sdk.Query.equal("compound_id", compoundId),
      sdk.Query.equal("building_num", buildingName),
      sdk.Query.isNull("deleted_at"),
    ]);
    return rows.map((row) => String(row.user_id ?? "").trim()).filter(Boolean);
  }

  if (channelType === "ADMIN_NOTIFICATION" || channelType === "MAINTENANCE_NOTIFICATION") {
    const rows = await listAllUserApartments(databases, databaseId, [
      sdk.Query.equal("compound_id", compoundId),
      sdk.Query.isNull("deleted_at"),
    ]);
    return rows.map((row) => String(row.user_id ?? "").trim()).filter(Boolean);
  }

  return [];
}

module.exports = async (context) => {
  const log = typeof context.log === "function" ? context.log : () => {};
  const errorLog = typeof context.error === "function" ? context.error : log;

  try {
    if (!isTrustedEventInvocation(context)) {
      return context.res.json(
        { ok: false, error: "forbidden", message: "Only Appwrite events are allowed." },
        403
      );
    }

    const body = parseBody(context.req?.body);
    const messageRow = extractRowFromEventPayload(body);
    if (!messageRow) {
      return context.res.json(
        { ok: true, skipped: true, reason: "missing_message_payload" },
        200
      );
    }

    const authorId = String(messageRow.author_id ?? "").trim();
    const channelId = String(messageRow.channel_id ?? "").trim();
    const messageId = String(messageRow.$id ?? messageRow.id ?? "").trim();
    if (!authorId || !channelId || !messageId) {
      return context.res.json(
        { ok: true, skipped: true, reason: "missing_author_or_channel_or_message_id" },
        200
      );
    }

    const { endpoint, projectId, apiKey, databaseId } = resolveClientConfig();
    const client = new sdk.Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
    const databases = new sdk.Databases(client);
    const messaging = new sdk.Messaging(client);

    const channelDoc = await databases.getDocument(databaseId, COLLECTION_CHANNELS, channelId);
    const recipientUserIds = await resolveRecipientUserIds(databases, databaseId, channelDoc);
    const targetUsers = [...new Set(recipientUserIds)].filter((userId) => userId && userId !== authorId);
    if (targetUsers.length === 0) {
      return context.res.json(
        { ok: true, skipped: true, reason: "no_recipients_after_filter" },
        200
      );
    }

    const channelType = String(channelDoc.type ?? "").trim();
    const {
      notificationTitle,
      notificationFallbackBody,
      notificationChannel,
    } = resolveNotificationProfile(channelType);
    const bodyText = truncateText(messageRow.text) || notificationFallbackBody;

    await messaging.createPush(
      sdk.ID.unique(),
      notificationTitle,
      bodyText,
      [],
      targetUsers,
      [],
      {
        type: "chat_message",
        messageId,
        channelId,
        channelType,
        notificationChannel,
      }
    );

    return context.res.json({
      ok: true,
      notifiedUsers: targetUsers.length,
      messageId,
      channelId,
      channelType,
    });
  } catch (error) {
    const message = error?.message ?? String(error);
    errorLog(message);
    return context.res.json(
      {
        ok: false,
        error: "notify_new_message_failed",
        message: "Unable to process notification request.",
      },
      500
    );
  }
};
