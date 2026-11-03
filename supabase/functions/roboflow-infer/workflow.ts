// Calls NavAble's Roboflow workflow. Ported from worker/src/workflow.js.

const WORKSPACE_NAME = "nav-able";
const WORKFLOW_ID =
  "navable-accessibility-detection-vnavable-accessibility-detection-2-rfdetr-small-t1-logic";
const WORKFLOW_ENDPOINT =
  `https://serverless.roboflow.com/${WORKSPACE_NAME}/workflows/${WORKFLOW_ID}`;
const OUTPUT_NAME = "predictions";

export class WorkflowError extends Error {
  code: string;
  retryable?: boolean;

  constructor(message: string, code: string, options?: { cause?: unknown }) {
    super(message, options);
    this.name = "WorkflowError";
    this.code = code;
  }
}

// Keeps small, useful fields (class, confidence, box) and drops large ones
// such as masks, polygons and images.
function sanitize(value: unknown, key = "", depth = 0): unknown {
  if (
    depth > 2 ||
    /(^|_)(points?|polygons?|masks?|image|base64|visualization)(_|$)/i.test(key)
  ) {
    return undefined;
  }
  if (
    value === null || typeof value === "boolean" || typeof value === "number"
  ) return value;
  if (typeof value === "string") return value.length <= 128 ? value : undefined;
  if (Array.isArray(value)) {
    return value.slice(0, 20)
      .map((item) => sanitize(item, key, depth + 1))
      .filter((item) => item !== undefined);
  }
  if (typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [childKey, child] of Object.entries(value).slice(0, 16)) {
      const safe = sanitize(child, childKey, depth + 1);
      if (safe !== undefined) result[childKey] = safe;
    }
    return result;
  }
  return undefined;
}

export type WorkflowResult = {
  image: { width: number | null; height: number | null };
  detections: Record<string, unknown>[];
};

export function parseWorkflowResponse(responseBody: unknown): WorkflowResult {
  const result = Array.isArray(responseBody) ? responseBody[0] : responseBody;
  // deno-lint-ignore no-explicit-any
  const output = (result as any)?.[OUTPUT_NAME];
  if (
    !output || typeof output !== "object" || !Array.isArray(output.predictions)
  ) {
    throw new WorkflowError(
      `Roboflow response did not contain the expected "${OUTPUT_NAME}.predictions" array.`,
      "INVALID_WORKFLOW_RESPONSE",
    );
  }
  const image = output.image && typeof output.image === "object"
    ? {
      width: Number.isFinite(output.image.width) ? output.image.width : null,
      height: Number.isFinite(output.image.height) ? output.image.height : null,
    }
    : { width: null, height: null };
  const detections = output.predictions
    .slice(0, 20)
    .map((item: unknown) => sanitize(item))
    .filter((item: unknown) =>
      item && typeof item === "object" && !Array.isArray(item)
    ) as Record<string, unknown>[];
  return { image, detections };
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export async function runWorkflow(
  workflowBody: string,
  apiKey: string,
  fetchImpl: typeof fetch = fetch,
): Promise<WorkflowResult> {
  let lastError: WorkflowError | undefined;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25000);
    try {
      const response = await fetchImpl(WORKFLOW_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: workflowBody,
        signal: controller.signal,
      });
      if (!response.ok) {
        const error = new WorkflowError(
          `Roboflow returned HTTP ${response.status}.`,
          "WORKFLOW_HTTP_ERROR",
        );
        error.retryable = response.status === 408 || response.status === 429 ||
          response.status >= 500;
        throw error;
      }
      let responseBody: unknown;
      try {
        responseBody = await response.json();
      } catch (cause) {
        throw new WorkflowError(
          "Roboflow returned invalid JSON.",
          "INVALID_WORKFLOW_JSON",
          { cause },
        );
      }
      return parseWorkflowResponse(responseBody);
    } catch (error) {
      const isTimeout = (error as Error)?.name === "AbortError";
      const typed = error instanceof WorkflowError ? error : new WorkflowError(
        isTimeout ? "Roboflow request timed out." : "Could not reach Roboflow.",
        isTimeout ? "WORKFLOW_TIMEOUT" : "WORKFLOW_NETWORK_ERROR",
        { cause: error },
      );
      lastError = typed;
      const permanent = typed.retryable === false ||
        ["INVALID_WORKFLOW_RESPONSE", "INVALID_WORKFLOW_JSON"].includes(
          typed.code,
        );
      if (permanent || attempt === 2) throw typed;
      await sleep(300 * 2 ** attempt);
    } finally {
      clearTimeout(timeout);
    }
  }
  throw lastError ??
    new WorkflowError("Roboflow inference failed.", "WORKFLOW_FAILED");
}
