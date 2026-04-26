const sdk = require("node-appwrite");

const TYPE_TO_PREFIX = {
  maintenance: "MR",
  security: "SE",
  carservice: "CS",
  careservice: "CS",
};

function parseJsonBody(raw) {
  if (raw == null || raw === "") return {};
  if (typeof raw === "object" && !Array.isArray(raw)) return raw;
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw);
      return typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
        ? parsed
        : {};
    } catch {
      return {};
    }
  }
  return {};
}

function normalizeType(input) {
  return String(input ?? "")
    .trim()
    .toLowerCase()
    .replace(/[_\s-]+/g, "");
}

function formatCode(prefix, sequence) {
  return `${prefix}-${String(sequence).padStart(6, "0")}`;
}

async function allocateReportCode(databases, databaseId, countersCollectionId, prefix) {
  const counterDocId = prefix;

  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const doc = await databases.getDocument(databaseId, countersCollectionId, counterDocId);
      const nextRaw = Number(doc.next_number ?? 1);
      const sequence = Number.isFinite(nextRaw) && nextRaw > 0 ? Math.floor(nextRaw) : 1;
      const nextNumber = sequence + 1;
      await databases.updateDocument(databaseId, countersCollectionId, counterDocId, {
        next_number: nextNumber,
      });
      return { sequence, reportCode: formatCode(prefix, sequence) };
    } catch (error) {
      const isMissing = error?.code === 404;
      if (isMissing) {
        try {
          // First allocation for a prefix starts at 1, then stores 2 as the next number.
          await databases.createDocument(
            databaseId,
            countersCollectionId,
            counterDocId,
            { prefix, next_number: 2, version: 0 },
            [],
            []
          );
          return { sequence: 1, reportCode: formatCode(prefix, 1) };
        } catch (createError) {
          if (createError?.code === 409) {
            // Lost race creating the counter row; retry read/update.
            continue;
          }
          throw createError;
        }
      }
      if (error?.code === 409) {
        // Lost update race; retry.
        continue;
      }
      throw error;
    }
  }

  throw new Error(`Could not allocate report code for prefix ${prefix} after retries`);
}

module.exports = async (context) => {
  const log = typeof context.log === "function" ? context.log : () => {};

  try {
    const body = parseJsonBody(context.req?.body);
    const reportType = normalizeType(body.reportType ?? body.type);
    const prefix = TYPE_TO_PREFIX[reportType];

    if (!prefix) {
      return context.res.json(
        {
          error: "invalid_report_type",
          message: "reportType must be one of: maintenance, security, carservice",
        },
        400
      );
    }

    const endpoint = process.env.APPWRITE_FUNCTION_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projectId =
      process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
    const apiKey =
      process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
    const databaseId = process.env.APPWRITE_DATABASE_ID;
    const countersCollectionId =
      process.env.APPWRITE_REPORT_CODE_COUNTERS_COLLECTION_ID || "report_code_counters";

    if (!endpoint || !projectId || !apiKey || !databaseId) {
      return context.res.json(
        {
          error: "server_misconfigured",
          message:
            "Set APPWRITE_FUNCTION_ENDPOINT/APPWRITE_ENDPOINT, APPWRITE_FUNCTION_PROJECT_ID/APPWRITE_PROJECT_ID, APPWRITE_FUNCTION_API_KEY/APPWRITE_API_KEY, and APPWRITE_DATABASE_ID.",
        },
        500
      );
    }

    const client = new sdk.Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
    const databases = new sdk.Databases(client);

    const { sequence, reportCode } = await allocateReportCode(
      databases,
      databaseId,
      countersCollectionId,
      prefix
    );

    return context.res.json({
      report_type: reportType,
      prefix,
      sequence,
      report_code: reportCode,
    });
  } catch (error) {
    const message = error?.message ?? String(error);
    log(message);
    return context.res.json(
      {
        error: "report_code_generation_failed",
        message,
      },
      500
    );
  }
};
