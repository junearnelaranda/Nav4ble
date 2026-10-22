const WORKSPACE_NAME = 'nav-able';
const WORKFLOW_ID =
  'navable-accessibility-detection-vnavable-accessibility-detection-2-rfdetr-small-t1-logic';
const WORKFLOW_ENDPOINT =
  `https://serverless.roboflow.com/${WORKSPACE_NAME}/workflows/${WORKFLOW_ID}`;
const OUTPUT_NAME = 'predictions';

export class WorkflowError extends Error {
  constructor(message, code, options = {}) {
    super(message, options);
    this.name = 'WorkflowError';
    this.code = code;
  }
}

function sanitize(value, key = '', depth = 0) {
  if (depth > 2 || /(^|_)(points?|polygons?|masks?|image|base64|visualization)(_|$)/i.test(key)) {
    return undefined;
  }
  if (value === null || typeof value === 'boolean' || typeof value === 'number') return value;
  if (typeof value === 'string') return value.length <= 128 ? value : undefined;
  if (Array.isArray(value)) {
    return value.slice(0, 20)
      .map((item) => sanitize(item, key, depth + 1))
      .filter((item) => item !== undefined);
  }
  if (typeof value === 'object') {
    const result = {};
    for (const [childKey, child] of Object.entries(value).slice(0, 16)) {
      const safe = sanitize(child, childKey, depth + 1);
      if (safe !== undefined) result[childKey] = safe;
    }
    return result;
  }
  return undefined;
}

export function parseWorkflowResponse(responseBody) {
  const result = Array.isArray(responseBody) ? responseBody[0] : responseBody;
  const output = result && result[OUTPUT_NAME];
  if (!output || typeof output !== 'object' || !Array.isArray(output.predictions)) {
    throw new WorkflowError(
      `Roboflow response did not contain the expected "${OUTPUT_NAME}.predictions" array.`,
      'INVALID_WORKFLOW_RESPONSE',
    );
  }
  const image = output.image && typeof output.image === 'object'
    ? {
        width: Number.isFinite(output.image.width) ? output.image.width : null,
        height: Number.isFinite(output.image.height) ? output.image.height : null,
      }
    : { width: null, height: null };
  const detections = output.predictions
    .slice(0, 20)
    .map((item) => sanitize(item))
    .filter((item) => item && typeof item === 'object' && !Array.isArray(item));
  return { image, detections };
}

export async function runWorkflowForImage({ imageBase64, workflowBody, apiKey, fetchImpl = fetch }) {
  if (!apiKey) throw new WorkflowError('Roboflow key is not configured.', 'MISSING_API_KEY');
  if (typeof imageBase64 !== 'string' || !imageBase64) {
    throw new WorkflowError('A base64 image is required.', 'INVALID_IMAGE');
  }

  const body = workflowBody || JSON.stringify({ inputs: { image: { type: 'base64', value: imageBase64 } } });
  let lastError;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25000);
    try {
      const response = await fetchImpl(WORKFLOW_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body,
        signal: controller.signal,
      });
      if (!response.ok) {
        const retryable = response.status === 408 || response.status === 429 || response.status >= 500;
        const error = new WorkflowError(
          `Roboflow returned HTTP ${response.status}.`,
          'WORKFLOW_HTTP_ERROR',
        );
        error.retryable = retryable;
        if (retryable && attempt < 2) {
          lastError = error;
          await new Promise((resolve) => setTimeout(resolve, 300 * (2 ** attempt)));
          continue;
        }
        throw error;
      }
      let responseBody;
      try {
        responseBody = await response.json();
      } catch (cause) {
        throw new WorkflowError('Roboflow returned invalid JSON.', 'INVALID_WORKFLOW_JSON', { cause });
      }
      return parseWorkflowResponse(responseBody);
    } catch (error) {
      const isTimeout = error?.name === 'AbortError';
      const typed = error instanceof WorkflowError
        ? error
        : new WorkflowError(
            isTimeout ? 'Roboflow request timed out.' : 'Could not reach Roboflow.',
            isTimeout ? 'WORKFLOW_TIMEOUT' : 'WORKFLOW_NETWORK_ERROR',
            { cause: error },
          );
      lastError = typed;
      if (typed.retryable === false || ['INVALID_WORKFLOW_RESPONSE', 'INVALID_WORKFLOW_JSON'].includes(typed.code)) {
        throw typed;
      }
      if (attempt < 2) {
        await new Promise((resolve) => setTimeout(resolve, 300 * (2 ** attempt)));
        continue;
      }
      throw typed;
    } finally {
      clearTimeout(timeout);
    }
  }
  throw lastError || new WorkflowError('Roboflow inference failed.', 'WORKFLOW_FAILED');
}
