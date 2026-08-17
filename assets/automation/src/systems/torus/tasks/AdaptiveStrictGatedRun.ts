import fs from 'node:fs/promises';
import path from 'node:path';
import { Page } from '@playwright/test';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import { FreezeFlavor, JournalSnapshot } from '@tasks/AdaptiveJournal';
import { AdaptiveManifest } from '@tasks/AdaptiveManifest';
import { Violation, auditRun } from '@tasks/AdaptiveOracle';
import {
  StrictRunHandle,
  StrictRunOutcome,
  armStrictRun,
  driveStrictLesson,
} from '@tasks/AdaptiveStrictDriver';
import { assertSetupAnchor, failureText } from '@tasks/AdaptiveStrictAnchor';
import { ShadowHandle, armPoison, armShadowCapture } from '@tasks/AdaptiveShadowCapture';
import { HomeTask } from '@tasks/HomeTask';

/**
 * The routed spec's ONE failure boundary, extracted so every exit is
 * fault-injectable OFFLINE (gate-B round-5: the EXIT-EM writer position was
 * refused — per-site injection through the real boundary is the required
 * evidence, and this module is what makes that evidence cheap).
 *
 * It owns EVERYTHING from arming to the evidence dumps (gate-B0 r4/r5/r6 N1;
 * round-10 blocker 2; round-3 blocker 9): a fault ANYWHERE inside — arming,
 * poison, navigation, login, correlation, the anchor, the walk, the freeze,
 * the audit, either dump — seals the strict journal (bail), attempts the
 * shadow bail dump with a total cause extraction, and rethrows the ORIGINAL
 * error. It never judges: the caller owns the verdict assertions, and
 * `violations` is returned as EXACTLY the object `deps.audit` produced
 * (identity-witnessed) so the verdict boundary stays the unmodified auditRun
 * result (B4-VERDICT-S).
 */

export type GatedRunInputs = {
  sectionSlug: string;
  lessonTitle: string;
  searchTerm: string;
  manifest: AdaptiveManifest;
  /** PRIVATE evidence dir; dumps carry answer values — never inside the repo */
  shadowDir: string | null;
  /** poison one graded screen's submission in flight (bail runs only) */
  poisonScreen: string | null;
};

export type GatedRunResult = {
  outcome: StrictRunOutcome;
  flavor: FreezeFlavor | 'sealed';
  snapshot: JournalSnapshot;
  violations: Violation[];
};

export type GatedRunDeps = {
  armShadowCapture: typeof armShadowCapture;
  armStrictRun: typeof armStrictRun;
  armPoison: typeof armPoison;
  makeLessonTask: (page: Page) => AdaptiveLessonTask;
  makeHomeTask: (page: Page) => HomeTask;
  assertSetupAnchor: typeof assertSetupAnchor;
  driveStrictLesson: typeof driveStrictLesson;
  audit: typeof auditRun;
  writeFile: typeof fs.writeFile;
  now: () => number;
  log: (line: string) => void;
  warn: (line: string) => void;
};

/** Logging is never evidence: a hostile sink must not become a boundary exit
 * or displace the original error (gate-B round-6 blocker 11). */
const quietly = (fn: () => void): void => {
  try {
    fn();
  } catch {
    /* swallowed by contract */
  }
};

export const GATED_RUN_DEFAULTS: GatedRunDeps = {
  armShadowCapture,
  armStrictRun,
  armPoison,
  makeLessonTask: (page) => new AdaptiveLessonTask(page),
  makeHomeTask: (page) => new HomeTask(page),
  assertSetupAnchor,
  driveStrictLesson,
  audit: auditRun,
  writeFile: fs.writeFile,
  now: () => Date.now(),
  log: (line) => console.log(line),
  warn: (line) => console.warn(line),
};
Object.freeze(GATED_RUN_DEFAULTS);

export async function runGatedLote(
  page: Page,
  inputs: GatedRunInputs,
  deps: GatedRunDeps = GATED_RUN_DEFAULTS,
): Promise<GatedRunResult> {
  let shadow: ShadowHandle | null = null;
  let strict: StrictRunHandle | null = null;
  let poison: { fired(): boolean } | null = null;
  let outcome: StrictRunOutcome | null = null;
  let flavor: FreezeFlavor | 'sealed' | null = null;
  try {
    shadow = inputs.shadowDir ? await deps.armShadowCapture(page) : null;
    strict = deps.armStrictRun(page);
    // bail run: poison one graded screen's submission in flight — the strict
    // path must go red there; only legal with the shadow armed
    if (shadow && inputs.poisonScreen) {
      poison = await deps.armPoison(page, inputs.poisonScreen);
    }
    const adaptiveLesson = deps.makeLessonTask(page);

    await page.goto('/');
    await deps.makeHomeTask(page).login('student');
    await adaptiveLesson.openFromOutline(inputs.sectionSlug, inputs.lessonTitle, inputs.searchTerm);

    // B4-C4A (normative): the run's identity triple is frozen from the
    // server-rendered Delivery props immediately after opening the intended
    // page, BEFORE the driver acts; a run without it carries no correlation
    if (!(await strict.correlate())) {
      throw new Error('strict run correlation unavailable before the walk (MER-5865)');
    }
    // the section component is cross-anchored to the SETUP RESPONSE, the one
    // identity leg the rendered page cannot supply about itself (B4-C4A)
    deps.assertSetupAnchor(strict.journal, inputs.sectionSlug);
    if (shadow) {
      const correlated = await shadow.correlate();
      deps.log(`[MER-5865 shadow] correlated=${correlated}`);
    }

    outcome = await deps.driveStrictLesson(adaptiveLesson.deck, inputs.manifest, strict.journal);

    // the journal decides the freeze: an unfinished walk never noted the
    // lesson end, so this seals; a finished one awaits the finalization
    flavor = await strict.finish('green');
    const snapshot = strict.snapshot();
    const violations = deps.audit(inputs.manifest, outcome.runRecord, snapshot);

    // evidence lands BEFORE the caller's verdict so a red run keeps its trail
    if (inputs.shadowDir) {
      const file = path.join(inputs.shadowDir, `lote-strict-${deps.now()}.json`);
      await deps.writeFile(
        file,
        JSON.stringify({ outcome, flavor, snapshot, violations }, null, 2),
      );
      deps.log(`[MER-5865 strict] run evidence: ${file}`);
    }
    if (shadow && inputs.shadowDir) {
      const shadowFlavor = await shadow.finish(outcome.kind === 'completed' ? 'green' : 'bail');
      const file = await shadow.dump(
        inputs.shadowDir,
        outcome.kind === 'completed' ? 'lote-green' : 'lote-bail',
        {
          outcome: outcome.kind === 'completed' ? 'green' : 'bail',
          flavor: shadowFlavor,
          walkError: outcome.kind === 'aborted' ? outcome.cause : null,
          poisonFired: poison?.fired() ? inputs.poisonScreen : null,
        },
      );
      deps.log(`[MER-5865 shadow] capture (${shadowFlavor}): ${file}`);
    }
    return { outcome, flavor, snapshot, violations };
  } catch (boundaryError) {
    // FAIL-TOTAL CLEANUP (round-3 blocker 9): every cleanup step is
    // individually guarded so a finish fault still attempts the dump, a dump
    // fault is reported without replacing the cause, and the ORIGINAL error
    // always crosses the boundary — the rethrow is unconditional.
    if (strict && flavor === null) await strict.finish('bail').catch(() => {});
    if (shadow && inputs.shadowDir) {
      const shadowFlavor = await shadow.finish('bail').catch(() => 'sealed' as const);
      // even the dump's ARGUMENT evaluation is guarded: a hostile fired()
      // here would displace the original error before the rethrow
      let poisonFired: string | null = null;
      try {
        poisonFired = poison?.fired() ? inputs.poisonScreen : null;
      } catch {
        poisonFired = null;
      }
      await shadow
        .dump(inputs.shadowDir, 'lote-bail', {
          outcome: 'bail',
          flavor: shadowFlavor,
          walkError: failureText(boundaryError),
          poisonFired,
        })
        .then(
          (file) =>
            quietly(() => deps.log(`[MER-5865 shadow] bail capture (${shadowFlavor}): ${file}`)),
          (dumpError) =>
            quietly(() =>
              deps.warn(`[MER-5865 shadow] bail dump FAILED: ${failureText(dumpError)}`),
            ),
        );
    }
    throw boundaryError;
  }
}
