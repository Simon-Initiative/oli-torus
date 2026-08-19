import { existsSync, realpathSync } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { Page } from '@playwright/test';
import { AdaptiveJournalRecorder } from '@tasks/AdaptiveJournal';
import { RunVisit } from '@tasks/AdaptiveOracle';

/**
 * MER-5865 step 3 — PASSIVE shadow capture. Arms the network journal beside
 * the SHIPPED strict walker without touching it: entry fences are stamped by
 * a DOM observer on the deck's `[model][context]` element (the same identity
 * surface `readScreenIdentity` reads), so visits carry journal-domain seqs
 * while the code under replacement stays byte-identical.
 *
 * B0-review note: in the final design (step 4) the DRIVER stamps fences at
 * its own identity read; observer-stamped fences are a shadow-only stand-in
 * and an intentional delta of this gate.
 *
 * Raw dumps contain parsed request bodies (answer values) — they go to the
 * PRIVATE shadow dir only, never the repository.
 */

export type ShadowIdentity = { id: string; resourceId: number; attemptGuid: string };

/** Raw dumps carry answer values: any destination inside a git repository is
 * refused up front — the contract is enforced, not advisory.
 * The destination directory is CREATED FIRST, then fully resolved with
 * realpath and validated, and that resolved path is the one written to
 *: a symlink anywhere in the requested chain is flattened before
 * the `.git` scan. LIMIT: validation and write still use pathnames —
 * a concurrent actor replacing a validated ancestor with a symlink between
 * the scan and the write can redirect the dump; a handle-based no-follow
 * write is owed before any capture on a shared/untrusted machine. */
const createPrivateDestination = async (dir: string): Promise<string> => {
  await fs.mkdir(path.resolve(dir), { recursive: true });
  const real = realpathSync(path.resolve(dir));
  let current = real;
  for (;;) {
    if (existsSync(path.join(current, '.git'))) {
      throw new Error(
        `[MER-5865 shadow] refusing to dump answer values inside a git repository: ${dir}`,
      );
    }
    const parent = path.dirname(current);
    if (parent === current) return real;
    current = parent;
  }
};

export type ShadowHandle = {
  recorder: AdaptiveJournalRecorder;
  visits: RunVisit[];
  /** call once the lesson page is loaded: reads the run correlation from the
   * delivery component's props (section slug, page slug, resource attempt) */
  correlate(): Promise<boolean>;
  /** call after the walk: green -> freeze, bail -> seal; then dump */
  finish(outcome: 'green' | 'bail'): Promise<'accepted' | 'completed-failure' | 'sealed'>;
  dump(dir: string, label: string, extra?: Record<string, unknown>): Promise<string>;
};

/**
 * Step-3 bail-run harness: ONE-SHOT in-flight blanking of the first graded
 * submission whose paths carry the given screen prefix — the shipped walker
 * must bail at that screen and the sealed journal must audit to a
 * same-screen violation. Harness-side only; the walker stays untouched.
 */
export async function armPoison(page: Page, screenPrefix: string): Promise<{ fired(): boolean }> {
  let fired = false;
  await page.route('**/state/course/**/activity_attempt/**', async (route) => {
    const request = route.request();
    if (fired || request.method() !== 'PUT') return route.continue();
    let body: { partInputs?: unknown[] } | null = null;
    try {
      body = request.postDataJSON() as { partInputs?: unknown[] } | null;
    } catch {
      return route.continue();
    }
    if (!body || !Array.isArray(body.partInputs)) return route.continue();
    let blanked = 0;
    for (const part of body.partInputs) {
      const response = (part as { response?: Record<string, unknown> | null })?.response;
      if (!response || typeof response !== 'object') continue;
      const input =
        response.input && typeof response.input === 'object'
          ? (response.input as Record<string, unknown>)
          : response;
      Object.values(input).forEach((item) => {
        const entry = item as { path?: unknown; value?: unknown } | null;
        if (!entry || typeof entry.path !== 'string') return;
        if (!entry.path.startsWith(`${screenPrefix}|`)) return;
        if ('value' in entry) {
          entry.value = '';
          blanked += 1;
        }
      });
    }
    if (blanked === 0) return route.continue();
    fired = true;
    console.log(`[MER-5865 shadow] POISON: blanked ${blanked} value(s) on ${screenPrefix}`);
    return route.continue({ postData: JSON.stringify(body) });
  });
  return { fired: () => fired };
}

/**
 * The page-binding stamp handler, GUARDED by liveness:
 * until the arm completes — and again after detach — a stamp observes NOTHING,
 * so the Playwright-irreversible binding install is inert by EXECUTION, not by
 * an unreachability argument. Exported so the guard is unit-executable.
 */
export function makeShadowStamp(
  recorder: AdaptiveJournalRecorder,
  visits: RunVisit[],
  isLive: () => boolean,
): (source: unknown, raw: ShadowIdentity) => void {
  return (_source, raw) => {
    if (!isLive()) return;
    const last = visits[visits.length - 1];
    if (last && last.screenId === raw.id && last.renderedAttemptGuid === raw.attemptGuid) return;
    const fence = recorder.core.issueFence(raw.id);
    visits.push({
      screenId: raw.id,
      entrySeq: fence.seq,
      renderedAttemptGuid: raw.attemptGuid,
      resourceId: raw.resourceId,
    });
  };
}

export async function armShadowCapture(page: Page): Promise<ShadowHandle> {
  const recorder = new AdaptiveJournalRecorder(page);
  const visits: RunVisit[] = [];
  let correlation: {
    sectionSlug: string;
    revisionSlug: string;
    resourceAttemptGuid: string;
  } | null = null;

  // FAIL-TOTALITY. Playwright can never UNinstall an
  // exposed binding or an init script, so both are LIVENESS-GATED instead:
  // the binding checks `live` on every stamp (executed guard, unit-witnessed)
  // and the init script only optional-chains the binding. `live` turns true
  // ONLY after every arming step — including the fail-atomic
  // recorder.attach(), which runs last — has succeeded, and turns false again
  // at detach, so a partially armed or finished capture observes nothing.
  let live = false;
  await page.exposeBinding(
    '__mer5865ShadowStamp',
    makeShadowStamp(recorder, visits, () => live),
  );

  await page.addInitScript(() => {
    const readIdentity = () => {
      const els = Array.from(document.querySelectorAll('[model][context]'));
      const last = els[els.length - 1];
      if (!last) return null;
      try {
        const model = JSON.parse(last.getAttribute('model') || '{}') as {
          id?: unknown;
          resourceId?: unknown;
          attemptGuid?: unknown;
        };
        if (
          typeof model.id === 'string' &&
          model.id &&
          typeof model.resourceId === 'number' &&
          typeof model.attemptGuid === 'string' &&
          model.attemptGuid
        ) {
          return {
            id: model.id,
            resourceId: model.resourceId,
            attemptGuid: model.attemptGuid,
          };
        }
      } catch {
        /* not parseable yet */
      }
      return null;
    };
    let lastKey = '';
    const scan = () => {
      const identity = readIdentity();
      if (!identity) return;
      const key = `${identity.id}|${identity.attemptGuid}`;
      if (key === lastKey) return;
      lastKey = key;
      (window as unknown as { __mer5865ShadowStamp?: (i: unknown) => void }).__mer5865ShadowStamp?.(
        identity,
      );
    };
    const observer = new MutationObserver(scan);
    const arm = () => {
      observer.observe(document.documentElement, {
        subtree: true,
        childList: true,
        attributes: true,
        attributeFilter: ['model', 'context'],
      });
      scan();
    };
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', arm);
    } else {
      arm();
    }
  });

  recorder.attach();
  live = true;

  return {
    recorder,
    visits,
    async correlate() {
      const props = await page
        .evaluate(() => {
          const el = document.querySelector('[data-react-class="Components.Delivery"]');
          try {
            return JSON.parse(el?.getAttribute('data-react-props') ?? 'null') as {
              sectionSlug?: string;
              pageSlug?: string;
              resourceAttemptGuid?: string;
            } | null;
          } catch {
            return null;
          }
        })
        .catch(() => null);
      if (!props?.sectionSlug || !props.pageSlug || !props.resourceAttemptGuid) return false;
      correlation = {
        sectionSlug: props.sectionSlug,
        revisionSlug: props.pageSlug,
        resourceAttemptGuid: props.resourceAttemptGuid,
      };
      recorder.core.setRunCorrelation(correlation);
      return true;
    },
    async finish(outcome) {
      try {
        if (outcome === 'green') {
          recorder.core.noteLessonEnd();
          try {
            return await recorder.awaitFreeze({ quiescenceMs: 750 });
          } catch {
            await recorder.seal();
            return 'sealed';
          }
        }
        await recorder.seal();
        return 'sealed';
      } finally {
        // the terminal snapshot is immutable — neither the page listeners nor
        // the irreversible binding may observe past it
        live = false;
        try {
          recorder.detach();
        } catch {
          /* already detached by the freeze path */
        }
      }
    },
    async dump(dir, label, extra = {}) {
      const target = await createPrivateDestination(dir);
      const file = path.join(target, `${label}-${Date.now()}.json`);
      // correlation rides along from the delivery props — the independent
      // SOURCE (DOM, not wire) the green envelope pins the finalization
      // against
      await fs.writeFile(
        file,
        JSON.stringify(
          { visits, correlation, snapshot: recorder.core.snapshot(), ...extra },
          null,
          1,
        ),
      );
      return file;
    },
  };
}
