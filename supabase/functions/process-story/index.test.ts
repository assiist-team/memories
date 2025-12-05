import { assertEquals } from "jsr:@std/assert/equals";
import { assertThrows } from "jsr:@std/assert/throws";

import { resolveStoryProcessingOutcome } from "./index.ts";

Deno.test("resolveStoryProcessingOutcome prefers generated results", () => {
  const outcome = resolveStoryProcessingOutcome({
    inputText: "input text value",
    narrativeResult: "narrative text value",
    titleResult: "Generated Title",
  });

  assertEquals(outcome, {
    narrative: "narrative text value",
    title: "Generated Title",
    titleFallbackUsed: false,
    fallbackSource: null,
  });
});

Deno.test("resolveStoryProcessingOutcome falls back to narrative when title missing", () => {
  const longNarrative =
    "This is a slightly longer narrative text that should be truncated for a fallback title.";
  const outcome = resolveStoryProcessingOutcome({
    inputText: "input text value",
    narrativeResult: longNarrative,
    titleResult: null,
  });

  assertEquals(outcome.titleFallbackUsed, true);
  assertEquals(outcome.fallbackSource, "narrative");
  assertEquals(outcome.title.endsWith("..."), true);
  assertEquals(outcome.narrative, longNarrative);
});

Deno.test("resolveStoryProcessingOutcome throws when both results empty", () => {
  assertThrows(() =>
    resolveStoryProcessingOutcome({
      inputText: "still captured text",
      narrativeResult: null,
      titleResult: null,
    })
  );
});
