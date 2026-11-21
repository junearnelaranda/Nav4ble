// Calls NavAble's Roboflow workflow. Ported from worker/src/workflow.js.

const WORKSPACE_NAME = "nav-able";
// The base workflow takes the model and a confidence floor as inputs. (The
// "...-logic" wrapper only passed the image, so the base workflow's 40%
// default dropped most real detections: this model rarely scores higher.)
const WORKFLOW_ID = "navable-accessibility-detection";
export const WORKFLOW_ENDPOINT =
  `https://serverless.roboflow.com/${WORKSPACE_NAME}/workflows/${WORKFLOW_ID}`;
const MODEL_ID = "nav-able/navable-accessibility-detection-2-rfdetr-small-t1";
const OUTPUT_NAME = "predictions";

// Roboflow returns everything above this; filterDetections then applies
// each feature's own cutoff.
const CONFIDENCE_FLOOR = 0.2;

// Per-feature cutoffs from the model's evaluation (optimal thresholds:
// ramp 0.33, elevator 0.39, restroom and tactile 0.24), set slightly toward
// suggesting more, since an administrator verifies every result. Elevator
// stays strict: the model mistakes ramps for elevators at about 27%.
const CLASS_CUTOFFS: Record<string, number> = {
  ramp: 0.3,
  elevator: 0.39,
  accessible_restroom: 0.3,
  tactile: 0.3,
  accessible_entrance: 0.3,
};
const DEFAULT_CUTOFF = 0.4;

export function workflowInputs(imageBase64: string) {
  return {
    image: { type: "base64", value: imageBase64 },
    model_id: MODEL_ID,
    confidence: CONFIDENCE_FLOOR,
  };
}

// Keeps detections at or above their feature's cutoff, one per feature
// (the most confident), best first.
export function filterDetections(
  detections: Record<string, unknown>[],
): Record<string, unknown>[] {
  const best = new Map<string, Record<string, unknown>>();
  for (const detection of detections) {
    const label = detection.class;
    const confidence = detection.confidence;
    if (typeof label !== "string" || !label) continue;
    if (typeof confidence !== "number" || !Number.isFinite(confidence)) continue;
    if (confidence < (CLASS_CUTOFFS[label] ?? DEFAULT_CUTOFF)) continue;
    const current = best.get(label);
    if (!current || confidence > (current.confidence as number)) {
      best.set(label, detection);
    }
  }
  return [...best.values()].sort((a, b) =>
    (b.confidence as number) - (a.confidence as number)
  );
}

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

// Roboflow's workflow endpoint answers {"outputs": [{predictions: ...}]};
// older answers were the result itself or a list of results. The
// "predictions" output is either {image, predictions: [...]} or the list.
export function parseWorkflowResponse(responseBody: unknown): WorkflowResult {
  // deno-lint-ignore no-explicit-any
  let result: any = responseBody;
  if (result && !Array.isArray(result) && Array.isArray(result.outputs)) {
    result = result.outputs;
  }
  if (Array.isArray(result)) result = result[0];
  // deno-lint-ignore no-explicit-any
  let output: any = result?.[OUTPUT_NAME];
  if (Array.isArray(output)) output = { predictions: output };
  if (
    !output || typeof output !== "object" || !Array.isArray(output.predictions)
  ) {
    // Field names only (never image data), to show what Roboflow sent.
    const keys = (value: unknown) =>
      value && typeof value === "object"
        ? Object.keys(value).slice(0, 8).join(",")
        : typeof value;
    throw new WorkflowError(
      `Roboflow response did not contain the expected "${OUTPUT_NAME}.predictions" array. ` +
        `Got top-level [${keys(responseBody)}], result [${keys(result)}], ` +
        `${OUTPUT_NAME} [${keys(result?.[OUTPUT_NAME])}].`,
      "INVALID_WORKFLOW_RESPONSE",
    );
  }
  const image = output.image && typeof output.image === "object"
    ? {
      width: Number.isFinite(output.image.width) ? output.image.width : null,
      height: Number.isFinite(output.image.height) ? output.image.height : null,
    }
    : { width: null, height: null };
  // The floor is low, so look at more raw guesses before filtering.
  const raw = output.predictions
    .slice(0, 300)
    .map((item: unknown) => sanitize(item))
    .filter((item: unknown) =>
      item && typeof item === "object" && !Array.isArray(item)
    ) as Record<string, unknown>[];
  return { image, detections: filterDetections(raw) };
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
