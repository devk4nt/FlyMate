import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type SupportedTable = "videos" | "quick_feedback_requests";

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: Record<string, unknown> | null;
  old_record: Record<string, unknown> | null;
}

interface UploadDetails {
  id: string;
  kind: string;
  uploaderName: string;
  uploaderID: string;
  studyName: string;
  title: string;
  durationSeconds: number;
  createdAt: string;
  focus: string | null;
}

const jsonHeaders = { "Content-Type": "application/json" };
const defaultAdminNotificationEmail = "flymate.team.contact@gmail.com";
const supportedTables = new Set<SupportedTable>([
  "videos",
  "quick_feedback_requests",
]);

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`${name} is not configured`);
  }
  return value;
}

function readString(
  record: Record<string, unknown>,
  key: string,
  fallback = "",
): string {
  const value = record[key];
  return typeof value === "string" ? value : fallback;
}

function readNumber(record: Record<string, unknown>, key: string): number {
  const value = record[key];
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatDuration(seconds: number): string {
  const roundedSeconds = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(roundedSeconds / 60);
  const remainder = roundedSeconds % 60;
  return minutes > 0 ? `${minutes}분 ${remainder}초` : `${remainder}초`;
}

function formatCreatedAt(createdAt: string): string {
  const date = new Date(createdAt);
  if (Number.isNaN(date.getTime())) {
    return createdAt || "확인 불가";
  }
  return new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function focusAreaLabel(value: string): string {
  switch (value) {
    case "expression":
      return "표정/시선";
    case "voice":
      return "말투/목소리";
    case "answer":
      return "답변 내용";
    case "overall":
      return "종합";
    default:
      return value;
  }
}

function buildEmailHTML(details: UploadDetails): string {
  const rows = [
    ["구분", details.kind],
    ["사용자", details.uploaderName],
    ["사용자 ID", details.uploaderID],
    ["스터디", details.studyName],
    ["영상 제목", details.title],
    ["영상 길이", formatDuration(details.durationSeconds)],
    ["업로드 시각", formatCreatedAt(details.createdAt)],
    ["영상 ID", details.id],
  ];

  if (details.focus) {
    rows.splice(6, 0, ["집중 피드백", details.focus]);
  }

  const tableRows = rows.map(([label, value]) => `
    <tr>
      <th style="padding:8px 12px;text-align:left;background:#f5f5f5;border:1px solid #ddd;white-space:nowrap">${escapeHTML(label)}</th>
      <td style="padding:8px 12px;border:1px solid #ddd">${escapeHTML(value)}</td>
    </tr>`).join("");

  return `
    <!doctype html>
    <html lang="ko">
      <body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#1f2937">
        <h2 style="margin-bottom:8px">새 피드백 영상이 등록되었습니다</h2>
        <p style="margin-top:0;color:#6b7280">FlyMate 영상 등록 완료 알림입니다.</p>
        <table style="border-collapse:collapse;font-size:14px">${tableRows}</table>
        <p style="margin-top:16px;color:#6b7280;font-size:12px">
          영상은 비공개 저장소에 보관되므로 이메일에 재생 링크를 포함하지 않았습니다.
        </p>
      </body>
    </html>`;
}

function buildEmailText(details: UploadDetails): string {
  const lines = [
    "새 피드백 영상이 등록되었습니다.",
    "",
    `구분: ${details.kind}`,
    `사용자: ${details.uploaderName}`,
    `사용자 ID: ${details.uploaderID}`,
    `스터디: ${details.studyName}`,
    `영상 제목: ${details.title}`,
    `영상 길이: ${formatDuration(details.durationSeconds)}`,
  ];
  if (details.focus) {
    lines.push(`집중 피드백: ${details.focus}`);
  }
  lines.push(
    `업로드 시각: ${formatCreatedAt(details.createdAt)}`,
    `영상 ID: ${details.id}`,
    "",
    "영상은 비공개 저장소에 보관되므로 이메일에 재생 링크를 포함하지 않았습니다.",
  );
  return lines.join("\n");
}

async function resolveUploadDetails(
  table: SupportedTable,
  record: Record<string, unknown>,
): Promise<UploadDetails> {
  const uploaderID = readString(record, "uploader_id");
  let uploaderName = readString(record, "uploader_name", "알 수 없는 사용자");
  let studyName = table === "videos" ? "알 수 없는 스터디" : "빠른 피드백";

  const supabaseURL = getRequiredEnv("SUPABASE_URL");
  const serviceRoleKey = getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseAdmin = createClient(supabaseURL, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (!uploaderName || uploaderName === "알 수 없는 사용자") {
    const { data: user, error } = await supabaseAdmin
      .from("users")
      .select("name")
      .eq("id", uploaderID)
      .maybeSingle();
    if (error) {
      console.error("Failed to fetch uploader name:", error.message);
    } else if (user?.name) {
      uploaderName = user.name;
    }
  }

  if (table === "videos") {
    const studyID = readString(record, "study_id");
    const { data: study, error } = await supabaseAdmin
      .from("studies")
      .select("name")
      .eq("id", studyID)
      .maybeSingle();
    if (error) {
      console.error("Failed to fetch study name:", error.message);
    } else if (study?.name) {
      studyName = study.name;
    }
  }

  const focusArea = readString(record, "focus_area");
  return {
    id: readString(record, "id"),
    kind: table === "videos" ? "스터디 피드백" : "빠른 피드백",
    uploaderName,
    uploaderID,
    studyName,
    title: readString(record, "title", "제목 없음"),
    durationSeconds: readNumber(record, "duration_seconds"),
    createdAt: readString(record, "created_at"),
    focus: focusArea ? focusAreaLabel(focusArea) : null,
  };
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    );
  }

  try {
    const webhookSecret = getRequiredEnv("VIDEO_UPLOAD_WEBHOOK_SECRET");
    if (req.headers.get("x-webhook-secret") !== webhookSecret) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: jsonHeaders },
      );
    }

    const payload = await req.json() as WebhookPayload;
    if (
      payload.type !== "INSERT" ||
      payload.schema !== "public" ||
      !supportedTables.has(payload.table as SupportedTable) ||
      !payload.record
    ) {
      return new Response(
        JSON.stringify({ message: "Ignored" }),
        { status: 200, headers: jsonHeaders },
      );
    }

    const table = payload.table as SupportedTable;
    const details = await resolveUploadDetails(table, payload.record);
    if (!details.id || !details.uploaderID) {
      return new Response(
        JSON.stringify({ error: "Invalid webhook record" }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const resendAPIKey = getRequiredEnv("RESEND_API_KEY");
    const recipient = Deno.env.get("ADMIN_NOTIFICATION_EMAIL")?.trim() ||
      defaultAdminNotificationEmail;
    const sender = getRequiredEnv("RESEND_FROM_EMAIL");
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendAPIKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": `flymate-video-upload/${table}/${details.id}`,
      },
      body: JSON.stringify({
        from: sender,
        to: [recipient],
        subject: `[FlyMate] 새 피드백 영상: ${details.title}`,
        html: buildEmailHTML(details),
        text: buildEmailText(details),
      }),
    });

    const resendBody = await resendResponse.text();
    if (!resendResponse.ok) {
      console.error(`Resend request failed (${resendResponse.status}):`, resendBody);
      return new Response(
        JSON.stringify({ error: "Failed to send email" }),
        { status: 502, headers: jsonHeaders },
      );
    }

    return new Response(
      JSON.stringify({ message: "Email sent" }),
      { status: 200, headers: jsonHeaders },
    );
  } catch (error) {
    console.error(
      "send-video-upload-email error:",
      error instanceof Error ? error.message : String(error),
    );
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
