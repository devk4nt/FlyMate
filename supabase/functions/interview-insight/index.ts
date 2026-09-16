import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import OpenAI, { toFile } from "npm:openai";

interface InsightFrame {
  time: number;
  jpegBase64: string;
}

interface InsightRequest {
  duration: number;
  audioBase64?: string | null;
  frames: InsightFrame[];
}

interface TranscriptSegment {
  start: number;
  end: number;
  text: string;
}

interface InsightSentenceResponse {
  start: number;
  text: string;
  strength: string | null;
  weakness: string | null;
  suggestion: string | null;
}

interface InsightResponse {
  summary: string;
  sentences: InsightSentenceResponse[];
}

const jsonHeaders = { "Content-Type": "application/json" };
const maxFrames = 36;

const systemPrompt = `지원자의 객실승무원 영상면접 연습 데이터를 분석하세요. 목표는 합격 여부나 사람의 성향을 판단하는 것이 아니라, 제공된 데이터에서 직접 확인할 수 있는 교정 가능한 표현과 행동을 찾아 다음 촬영에 적용할 피드백을 만드는 것입니다.

## 최우선 원칙: 근거 없는 판단 금지

- 제공된 전사, 시각, 시간 데이터에 없는 사실을 만들지 마세요.
- 관찰 사실과 해석을 구분하세요. 내부 분석에서는 시간 데이터를 근거로 사용하되, 사용자에게 보여주는 summary, strength, weakness, suggestion에는 시간, 초, 구간, 프레임 시각을 적지 마세요.
- 하나의 신호만으로 대본 낭독, 긴장, 자신감, 진정성, 성격, 감정, 건강 상태, 직무 역량이나 합격 가능성을 단정하지 마세요.
- 근거가 부족하면 평가하지 마세요. 모든 평가 항목을 억지로 채우지 마세요.
- "좋다", "부족하다", "자연스럽다" 같은 결론만 쓰지 말고 무엇이 그렇게 관찰됐는지 설명하세요.
- 지원자의 외모, 얼굴 생김새, 체형, 나이, 성별, 인종, 장애 여부 등 직무와 관계없는 특성을 평가하지 마세요.
- 헤어, 의상과 메이크업은 미적 매력이 아니라 얼굴을 가리는지, 배경과 구분되는지, 화면에서 단정하게 유지되는지만 평가하세요.
- 특정 스타일, 미소 형태, 촬영 장소나 고가 장비를 합격의 정답처럼 제시하지 마세요.

## 데이터별 허용 범위

전사 텍스트로 판단 가능한 항목:

- 질문에 대한 결론과 핵심 메시지가 답변 초반에 나타나는지
- 추상적인 장점 나열이 아니라 구체적인 상황, 판단, 행동과 결과가 포함되는지
- 고객 응대, 안전, 협업, 배려, 책임감, 문제 해결과의 연결이 실제 발언에 있는지
- 같은 의미의 반복, 장문, 불필요한 수식어, 문장 끝맺음과 추임새 사용

전사 텍스트로 판단할 수 없는 항목:

- 발음 정확성, 억양, 음색, 실제 목소리 크기, 음질, 말의 호감도
- 질문 내용이 제공되지 않았다면 답변이 질문 의도에 맞는지 여부
- 발언에 나오지 않은 경험이나 역량의 보유 여부

정지 프레임으로 판단 가능한 항목:

- 프레임에 나타난 표정, 시선 방향, 고개·어깨·상반신 위치
- 얼굴 식별 가능 여부, 밝기, 역광, 구도, 배경의 시각적 방해 요소

정지 프레임으로 판단할 수 없는 항목:

- 프레임 사이의 순간적인 표정 변화, 몸동작, 손동작 빈도와 움직임 속도
- 실제 시선 이동 과정이나 미소를 유지한 정확한 시간
- 사진 한 장만으로 대본이나 화면을 보았는지 여부

시각 정보는 같은 경향이 서로 다른 타임스탬프의 프레임에서 최소 2회 관찰될 때만 피드백에 사용하세요. 한 프레임에서만 보이면 sentences에 언급하지 마세요. 이미지가 없거나 식별이 어려우면 시각 피드백을 sentences에 작성하지 마세요.

## 답변 내용 평가

다음 흐름을 참고해 실제로 포함된 요소만 평가하세요.

핵심 결론 → 구체적인 상황 → 지원자의 판단과 행동 → 결과 또는 배운 점 → 객실승무원 업무와의 연결

- 모든 답변이 이 형식을 따라야 한다고 가정하지 마세요.
- "친절하다", "배려심이 있다", "협업 능력이 있다"는 자기 설명만으로 역량이 입증됐다고 판단하지 마세요. 실제 행동 근거가 있는지 확인하세요.
- 답변에 어떤 직무 행동이 없으면 지원자에게 그 역량이 없다고 쓰지 말고, "이 답변에서는 구체적인 행동 근거가 제시되지 않았다"고 표현하세요.
- 회사명이나 직무 용어의 사용 자체를 장점으로 평가하지 말고 개인 경험과 논리적으로 연결됐는지 확인하세요.
- 한 문장에 여러 강점을 나열하면 가장 중요한 메시지가 무엇인지 식별 가능한지 확인하세요.

## 대화형 전달 분석

핵심 목표는 준비한 내용을 대화하듯 설명하는지, 암기한 문장을 재생하는 인상을 줄 수 있는지를 보수적으로 살펴보는 것입니다.

- 제공된 발화 시간, 공백 제외 글자 수와 초당 글자 수는 자동 전사 구간별 참고값입니다. 고정된 기준으로 빠르거나 느리다고 단정하지 말고 이 지원자의 구간들 사이에서만 비교하세요.
- 자동 전사 구간의 경계는 자연스러운 문장 경계나 실제 무음을 보장하지 않습니다. 제공된 "이전 구간과의 간격"을 확정적인 침묵으로 표현하지 마세요.
- 속도 차이는 초당 글자 수가 지원자의 다른 여러 구간과 뚜렷하게 다를 때만 언급하고, 작은 차이에 의미를 부여하지 마세요.
- 추임새, 짧은 간격과 스스로 고쳐 말하기는 그 자체로 감점하지 마세요. 메시지를 반복적으로 방해하는 경우에만 개선점으로 작성하세요.

다음 세 범주 가운데 최소 2개 범주의 신호가 서로 가까운 시간대에 나타나고, 유사한 조합이 답변 전체에서 최소 2회 반복될 때만 암기 낭독 가능성을 언급하세요.

1. 시간 신호: 문장 내부로 보이는 위치의 2초 이상 구간 간격 또는 여러 구간의 지나치게 균일한 상대 속도
2. 문체 신호: 긴 문어체 문장이 연속되고 짧은 문장, 수정 표현 또는 의미 있는 호흡의 변화가 거의 없음
3. 시각 신호: 시간 신호와 가까운 여러 프레임에서 같은 방향의 시선 이탈이 반복됨

조건을 충족하더라도 "대본을 읽었다"고 단정하지 말고 "해당 구간 조합은 암기한 문장을 회상하는 인상을 줄 수 있다"고 표현하세요. 조건을 충족하지 않으면 암기 여부를 판단하지 마세요.

## 문장과 프레임 교차 확인

- 문장 피드백에 시각 정보를 연결하려면 문장 발화 구간 안이나 시작·종료 시각에서 약 3초 이내인 프레임만 사용하세요.
- 가까운 프레임이 없으면 그 문장의 표정, 시선이나 자세를 언급하지 마세요.
- 시간 데이터는 어떤 문장과 프레임을 연결할지 결정하는 내부 근거로만 사용하세요.
- summary, strength, weakness, suggestion에는 "12.4~18.1초", "0:10 프레임", "해당 구간" 같은 시간 위치 표현을 넣지 마세요.
- 피드백 텍스트에는 괄호나 대괄호를 사용한 부연 설명을 넣지 마세요.

## 문장 재구성

- 자동 전사는 시간 단위로 분할되므로 의미와 문법이 직접 이어지는 인접 구간만 자연스러운 문장으로 합치세요.
- 재구성한 문장의 start에는 첫 전사 구간의 start 값을 사용하세요.
- 지원자가 말한 내용을 순서대로 빠짐없이 포함하세요.
- 명백한 오탈자와 띄어쓰기만 고치고, 내용을 요약·의역·보완하거나 새로운 표현을 추가하지 마세요.
- 실제 반복 발언을 삭제하지 마세요.
- 경계가 불확실하면 무리하게 합치지 말고 원래 구간에 가깝게 유지하세요.

## 피드백 작성

- 문장마다 가장 중요한 피드백 하나만 선택하세요. 여러 문제나 장점을 나열하지 마세요.
- 유지할 점이 핵심이면 strength만 짧은 한 문장으로 작성하고 weakness와 suggestion은 null로 작성하세요.
- 개선할 점이 핵심이면 weakness와 suggestion만 각각 짧은 한 문장으로 작성하고 strength는 null로 작성하세요.
- strength: 무엇을 유지할지 핵심만 작성하세요. 근거 시각이나 수치를 반복하지 말고 45자 안팎을 권장합니다.
- weakness: 무엇이 메시지를 방해하는지 핵심만 작성하세요. 시간이나 프레임을 언급하지 말고 45자 안팎을 권장합니다.
- suggestion: 다음 촬영에서 바로 실행할 행동 하나만 명령형이 아닌 친절한 제안으로 작성하세요. 45자 안팎을 권장합니다.
- strength와 weakness가 모두 null인 문장은 만들지 마세요.
- 같은 조언을 모든 문장에 반복하지 마세요.
- 시각적 장점 때문에 내용상의 문제를 상쇄하거나, 내용상의 장점 때문에 시각적 문제를 추정하지 마세요.
- summary, strength, weakness, suggestion에는 괄호, 대괄호, 타임코드와 시간대 설명을 사용하지 마세요.

## summary와 출력

- summary는 핵심만 담은 2문장으로 작성하고 전체 180자를 넘기지 마세요.
- 첫 문장에는 답변 전체에서 가장 분명한 유지점 하나만 작성하세요.
- 두 번째 문장에는 다음 촬영에서 가장 먼저 바꿀 한 가지와 실행 방법을 함께 작성하세요.
- 원본 음성으로만 판단 가능한 항목을 별도 문장으로 반복 안내하지 마세요. 해당 항목을 평가에서 제외하는 것으로 충분합니다.
- 프레임이 없거나 식별하기 어려운 경우에만 두 번째 문장 끝에 시각 요소는 확인하기 어려웠다고 짧게 덧붙이세요.
- 합격·불합격, 합격 가능성, 점수, 등급과 성격 평가는 출력하지 마세요.
- 전사가 없으면 sentences는 빈 배열로 두고 프레임에서 확인되는 내용만 summary에 작성하세요.
- 모든 텍스트는 마크다운 없이 평문으로 작성하세요.
- 반드시 제공된 JSON 스키마에 맞는 값만 출력하세요.`;

const insightSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    summary: { type: "string" },
    sentences: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          start: { type: "number" },
          text: { type: "string" },
          strength: { type: ["string", "null"] },
          weakness: { type: ["string", "null"] },
          suggestion: { type: ["string", "null"] },
        },
        required: ["start", "text", "strength", "weakness", "suggestion"],
      },
    },
  },
  required: ["summary", "sentences"],
};

function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new Error(`${name} is not configured`);
  }
  return value;
}

function formatTime(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(total / 60);
  const remainder = total % 60;
  return `${minutes}:${String(remainder).padStart(2, "0")}`;
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function removeTimestampAnnotations(value: string | null): string | null {
  if (value === null) return null;

  const cleaned = value
    .replace(
      /\s*[\(\[][^\)\]]*(?:\d{1,2}:\d{2}|\d+(?:\.\d+)?\s*(?:초|~|–|-)|프레임|시간대|구간)[^\)\]]*[\)\]]/g,
      "",
    )
    .replace(
      /(?:\d+(?:\.\d+)?\s*[~–-]\s*\d+(?:\.\d+)?\s*초\s*(?:구간)?|\d{1,2}:\d{2}(?:\s*(?:프레임|시점))?)(?:에서|에는|의)?\s*/g,
      "",
    )
    .replace(/해당\s*(?:시간대|구간|프레임|시점)(?:에서|에는|의)?\s*/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();

  return cleaned.length > 0 ? cleaned : null;
}

function sanitizeInsight(insight: InsightResponse): InsightResponse {
  return {
    summary: removeTimestampAnnotations(insight.summary) ??
      "문장별 핵심 피드백을 확인해 주세요.",
    sentences: insight.sentences.map((sentence) => {
      const strength = removeTimestampAnnotations(sentence.strength);
      const weakness = removeTimestampAnnotations(sentence.weakness);
      const suggestion = removeTimestampAnnotations(sentence.suggestion);
      return {
        ...sentence,
        strength: weakness === null ? strength : null,
        weakness,
        suggestion,
      };
    }),
  };
}

async function transcribe(
  openai: OpenAI,
  audioBase64: string,
): Promise<TranscriptSegment[]> {
  const transcription = await openai.audio.transcriptions.create({
    file: await toFile(base64ToBytes(audioBase64), "answer.m4a", {
      type: "audio/m4a",
    }),
    model: "whisper-1",
    language: "ko",
    response_format: "verbose_json",
    timestamp_granularities: ["segment"],
  });
  return (transcription.segments ?? [])
    .map((segment) => ({
      start: segment.start,
      end: segment.end,
      text: segment.text.trim(),
    }))
    .filter((segment) => segment.text.length > 0);
}

type ContentPart =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string; detail: "low" } };

function buildUserContent(
  request: InsightRequest,
  segments: TranscriptSegment[],
): ContentPart[] {
  const content: ContentPart[] = [
    {
      type: "text",
      text: `영상 길이: ${Math.round(request.duration)}초\n아래는 영상에서 캡처한 프레임(시간 순)입니다.`,
    },
  ];

  for (const frame of (request.frames ?? []).slice(0, maxFrames)) {
    content.push({ type: "text", text: `프레임 ${formatTime(frame.time)}:` });
    content.push({
      type: "image_url",
      image_url: {
        url: `data:image/jpeg;base64,${frame.jpegBase64}`,
        detail: "low",
      },
    });
  }

  if (segments.length > 0) {
    const lines = ["전사 문장 목록 (자동 전사, 시각 순):"];
    let previousEnd = 0;
    for (const segment of segments) {
      const gap = Math.max(0, segment.start - previousEnd);
      const duration = Math.max(0.1, segment.end - segment.start);
      const characterCount = Array.from(segment.text.replace(/\s/g, "")).length;
      const charactersPerSecond = characterCount / duration;
      lines.push(
        `- start=${segment.start.toFixed(1)}, end=${segment.end.toFixed(1)}, duration=${duration.toFixed(1)}초, 이전 전사 구간과의 간격=${gap.toFixed(1)}초, 공백 제외 글자 수=${characterCount}, 초당 글자 수=${charactersPerSecond.toFixed(1)}: ${segment.text}`,
      );
      previousEnd = segment.end;
    }
    content.push({ type: "text", text: lines.join("\n") });
  } else {
    content.push({
      type: "text",
      text: "전사 문장: 없음 (음성 추출 실패 또는 무음)",
    });
  }

  content.push({
    type: "text",
    text: "위 데이터를 바탕으로 결과 형식(JSON)에 맞춰 문장별 분석을 작성해 주세요.",
  });
  return content;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  try {
    const request = (await req.json()) as InsightRequest;
    const hasFrames = Array.isArray(request?.frames) && request.frames.length > 0;
    const hasAudio = typeof request?.audioBase64 === "string" &&
      request.audioBase64.length > 0;
    if (typeof request?.duration !== "number" || (!hasFrames && !hasAudio)) {
      return new Response(JSON.stringify({ error: "Invalid request payload" }), {
        status: 400,
        headers: jsonHeaders,
      });
    }

    const openai = new OpenAI({ apiKey: getRequiredEnv("OPENAI_API_KEY") });
    const segments = hasAudio
      ? await transcribe(openai, request.audioBase64 as string)
      : [];

    const response = await openai.chat.completions.create({
      model: "gpt-5-mini",
      // 문장별 피드백은 문장 수에 비례해 길어지므로 여유 있게 잡는다
      max_completion_tokens: 8192,
      reasoning_effort: "low",
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "interview_insight",
          strict: true,
          schema: insightSchema,
        },
      },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: buildUserContent(request, segments) },
      ],
    });

    const content = response.choices[0]?.message?.content?.trim() ?? "";
    if (!content) {
      throw new Error("empty response from model");
    }
    const insight = sanitizeInsight(JSON.parse(content) as InsightResponse);

    return new Response(JSON.stringify({ insight }), { headers: jsonHeaders });
  } catch (error) {
    console.error("interview-insight error:", error);
    return new Response(
      JSON.stringify({ error: "분석 생성에 실패했어요. 잠시 후 다시 시도해 주세요." }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
