/**
 * Appwrite Function: create direct-upload asset on Gumlet.
 *
 * Env:
 * - GUMLET_API_KEY (required)
 * - GUMLET_SOURCE_ID or GUMLET_COLLECTION_ID — Gumlet workspace / source id (see Direct Upload docs)
 *
 * Client JSON body: { filename?, mime?, size? }
 */

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

function coerceSourceId(raw) {
  const s = String(raw).trim();
  if (/^\d+$/.test(s)) return Number(s);
  return s;
}

function playbackFromPayload(data) {
  if (!data || typeof data !== "object") return null;
  if (typeof data.playback_url === "string" && data.playback_url) return data.playback_url;
  const out = data.output;
  if (out && typeof out === "object") {
    if (typeof out.playback_url === "string" && out.playback_url) return out.playback_url;
    if (typeof out.hls === "string" && out.hls) return out.hls;
  }
  return null;
}

module.exports = async (context) => {
  const log = typeof context.log === "function" ? context.log : () => {};

  try {
    const body = parseJsonBody(context.req?.body);
    const filename = body.filename || body.name || "upload";
    const mime =
      typeof body.mime === "string" ? body.mime.toLowerCase().trim() : "";
    const isAudio = mime.startsWith("audio/");

    const apiKey = process.env.GUMLET_API_KEY;
    const sourceRaw = process.env.GUMLET_SOURCE_ID || process.env.GUMLET_COLLECTION_ID;

    if (!apiKey) {
      return context.res.json({
        error: "server_misconfigured",
        message: "Set GUMLET_API_KEY on this function",
      });
    }
    if (!sourceRaw) {
      return context.res.json({
        error: "server_misconfigured",
        message:
          "Set GUMLET_SOURCE_ID (Gumlet workspace / source id from Direct Upload docs). " +
          "GUMLET_COLLECTION_ID is accepted as an alias.",
      });
    }

    // OpenAPI: format is ABR (HLS+DASH) or MP4. Voice: MP4 + audio_only avoids ABR/resolution quirks.
    const workspaceId = String(coerceSourceId(sourceRaw));
    const gumletPayload = {
      collection_id: workspaceId,
      title: filename,
    };

    if (isAudio) {
      gumletPayload.format = "MP4";
      gumletPayload.audio_only = true;
    } else {
      gumletPayload.format = "ABR";
      gumletPayload.resolution = "240p,360p";
    }

    if (process.env.GUMLET_KEEP_ORIGINAL === "false") {
      gumletPayload.keep_original = false;
    }

    const response = await fetch("https://api.gumlet.com/v1/video/assets/upload", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(gumletPayload),
    });

    const text = await response.text();
    let data;
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { raw: text };
    }

    if (!response.ok) {
      log(`Gumlet HTTP ${response.status}: ${text?.slice?.(0, 500) ?? text}`);
      return context.res.json({
        error: "gumlet_api_error",
        gumlet_status: response.status,
        gumlet_response: data,
      });
    }

    const uploadUrl = data.upload_url;
    const assetId = data.asset_id;
    const playbackUrl = playbackFromPayload(data);

    if (!uploadUrl || assetId == null || assetId === "") {
      log(`Unexpected Gumlet body: ${text?.slice?.(0, 800) ?? text}`);
      return context.res.json({
        error: "gumlet_unexpected_response",
        gumlet_response: data,
      });
    }

    return context.res.json({
      upload_url: uploadUrl,
      asset_id: String(assetId),
      playback_url: playbackUrl,
    });
  } catch (err) {
    const message = err?.message ?? String(err);
    log(message);
    return context.res.json({
      error: "function_exception",
      message,
    });
  }
};
