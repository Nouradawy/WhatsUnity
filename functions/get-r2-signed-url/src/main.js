const { S3Client, PutObjectCommand, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

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

module.exports = async (context) => {
  const log = typeof context.log === "function" ? context.log : () => {};

  try {
    const body = parseJsonBody(context.req?.body);
    const filename = body.filename != null ? String(body.filename) : "upload.bin";
    const mime =
      typeof body.mime === "string" && body.mime.trim() !== ""
        ? body.mime.trim()
        : "application/octet-stream";

    const endpoint = process.env.R2_ENDPOINT;
    const bucket = process.env.R2_BUCKET;
    const accessKeyId = process.env.R2_ACCESS_KEY_ID;
    const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
    const publicDomain = process.env.R2_PUBLIC_DOMAIN;

    if (!endpoint || !bucket || !accessKeyId || !secretAccessKey || !publicDomain) {
      return context.res.json({
        error: "server_misconfigured",
        message:
          "Set R2_ENDPOINT, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_PUBLIC_DOMAIN on this function.",
      });
    }

    const s3 = new S3Client({
      region: "auto",
      endpoint,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
    const key = `uploads/${Date.now()}_${safeName}`;

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: mime,
    });

    const signedPutUrl = await getSignedUrl(s3, command, { expiresIn: 3600 });

    const base = String(publicDomain).replace(/\/$/, "");
    const publicUrl = `${base}/${key}`;

    // Presigned GET so images work even when the bucket has no public custom domain.
    // SigV4 max expiry is typically 7 days (604800s).
    const readUrl = await getSignedUrl(
      s3,
      new GetObjectCommand({ Bucket: bucket, Key: key }),
      { expiresIn: 604800 },
    );

    return context.res.json({
      upload_url: signedPutUrl,
      public_url: publicUrl,
      read_url: readUrl,
      url: readUrl,
      file_url: readUrl,
      filename: key,
    });
  } catch (err) {
    const message = err?.message ?? String(err);
    log(message);
    return context.res.json({
      error: "presign_failed",
      message,
    });
  }
};
