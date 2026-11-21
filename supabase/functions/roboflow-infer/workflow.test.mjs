// Run with: node --test supabase/functions/roboflow-infer/
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  filterDetections,
  parseWorkflowResponse,
  WORKFLOW_ENDPOINT,
  workflowInputs,
} from "./workflow.ts";

// Real scores from a ramp photo, with the workflow's 40% cutoff turned off.
const rampPhoto = [
  { class: "ramp", confidence: 0.4026 },
  { class: "ramp", confidence: 0.3794 },
  { class: "ramp", confidence: 0.2802 },
  { class: "elevator", confidence: 0.2732 },
  { class: "accessible_entrance", confidence: 0.2362 },
];

test("a ramp scoring under 40% is still suggested", () => {
  const kept = filterDetections([{ class: "ramp", confidence: 0.31 }]);
  assert.deepEqual(kept.map((d) => d.class), ["ramp"]);
});

test("each feature uses its own cutoff", () => {
  const kept = filterDetections(rampPhoto);
  // The elevator guess (27%) is under the elevator cutoff (39%).
  assert.deepEqual(kept.map((d) => d.class), ["ramp"]);
});

test("only the best guess per feature is kept, best first", () => {
  const kept = filterDetections([
    { class: "tactile", confidence: 0.35 },
    { class: "ramp", confidence: 0.5 },
    { class: "ramp", confidence: 0.45 },
    { class: "tactile", confidence: 0.6 },
  ]);
  assert.deepEqual(kept.map((d) => [d.class, d.confidence]), [
    ["tactile", 0.6],
    ["ramp", 0.5],
  ]);
});

test("an unknown label needs at least 40%", () => {
  assert.equal(filterDetections([{ class: "stairs", confidence: 0.39 }]).length, 0);
  assert.equal(filterDetections([{ class: "stairs", confidence: 0.41 }]).length, 1);
});

test("detections without a label or score are dropped", () => {
  assert.equal(filterDetections([{ confidence: 0.9 }, { class: "ramp" }]).length, 0);
});

test("the workflow is asked for low scores, so the cutoffs can apply", () => {
  const inputs = workflowInputs("aGVsbG8=");
  assert.equal(inputs.image.value, "aGVsbG8=");
  assert.ok(inputs.confidence <= 0.25);
  assert.equal(inputs.model_id, "nav-able/navable-accessibility-detection-2-rfdetr-small-t1");
  assert.match(WORKFLOW_ENDPOINT, /\/workflows\/navable-accessibility-detection$/);
});

test("parsed workflow responses are filtered", () => {
  const result = parseWorkflowResponse({
    outputs: [{ predictions: { image: { width: 1024, height: 768 }, predictions: rampPhoto } }],
  });
  assert.deepEqual(result.image, { width: 1024, height: 768 });
  assert.deepEqual(result.detections.map((d) => d.class), ["ramp"]);
});
