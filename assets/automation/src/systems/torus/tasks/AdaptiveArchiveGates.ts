import type {
  AdaptiveManifest,
  AnswerOperation,
  GateOperation,
  ScreenDefinition,
} from './AdaptiveManifest';
import { validateRouteCoverage } from './AdaptiveManifest';
import { FamilyEntry, resolveFamily } from './AdaptiveFamilyRegistry';
import {
  RawArchivePage,
  RawScreen,
  deriveArchiveFacts,
  deriveScreenRole,
  mcqPartSpec,
} from './AdaptiveArchiveReader';

/**
 * Build gates that judge the manifest against the RAW archive ( * ). The completeness half reuses the committed `validateRouteCoverage`
 * — the gate is right, its INPUT was the extractor's own JSON; here the same
 * gate runs on facts derived by the independent reader, so extractor and
 * manifest can no longer agree with each other about the archive.
 */

const fail = (msg: string): never => {
  throw new Error(`archive gate: ${msg}`);
};

const screenById = (page: RawArchivePage, id: string): RawScreen | undefined =>
  page.screens.filter((s) => s.id === id)[0];

const answerOperations = (screen: ScreenDefinition): AnswerOperation[] =>
  (screen.operations ?? []).filter((op): op is AnswerOperation => op.kind === 'answer');

const gateOperations = (screen: ScreenDefinition): GateOperation[] =>
  (screen.operations ?? []).filter((op): op is GateOperation => op.kind === 'gate');

/** The part type each gate directive drives — the archive must render exactly one. */
const GATE_PART_TYPES: Record<string, ReadonlyArray<string>> = {
  carousel_view: ['janus-image-carousel'],
  flashcard_flip_all: ['janus-flashcards'],
  video_start: ['janus-video'],
};

/**
 * Registry metadata is the manifest's claim about the archive: the resolved
 * entry must actually own a part that the archive renders on that screen, and
 * for CAPI families the archive's widget src must carry the declared MAJOR
 * (§6.8 — the archive pins srcs at a major wildcard, so major is all that is
 * declarable). This is `detect`'s offline half: a wrong-but-valid resolution
 * fails here, before it can drive someone else's widget.
 */
function assertOwnedPart(entry: FamilyEntry, operation: AnswerOperation, screen: RawScreen): void {
  const at = `screen "${screen.id}" operation "${operation.id}"`;
  if (entry.capiWidget) {
    const matches = screen.parts.filter(
      (p) =>
        p.type === 'janus-capi-iframe' &&
        typeof p.src === 'string' &&
        p.src.indexOf(`/${entry.family}/`) !== -1,
    );
    if (matches.length === 0) {
      fail(`${at} declares family "${entry.family}", which no capi iframe on that screen serves`);
    }
    if (matches.length > 1) {
      fail(`${at} matches ${matches.length} capi iframes of family "${entry.family}" — ambiguous`);
    }
    const src = matches[0].src as string;
    const tail = src.slice(src.indexOf(`/${entry.family}/`) + entry.family.length + 2);
    const major = tail.replace(/^prod\//, '').split('.')[0];
    if (major !== entry.version) {
      fail(
        `${at} declares version "${entry.version}" but the archive pins family ` +
          `"${entry.family}" at major "${major}"`,
      );
    }
    return;
  }
  const declaredPartId = operation.directive.part_id;
  const owned = screen.parts.filter((p) => entry.partTypes.indexOf(p.type) !== -1);
  if (owned.length === 0) {
    fail(
      `${at} declares family "${entry.family}", which owns ${entry.partTypes.join('|')} — the ` +
        'archive renders no such part on that screen',
    );
  }
  if (typeof declaredPartId === 'string') {
    if (!owned.some((p) => p.id === declaredPartId)) {
      fail(
        `${at} names part "${declaredPartId}", which the archive does not render as ${entry.partTypes.join('|')}`,
      );
    }
    assertModeMatchesArchive(entry, operation, screen, declaredPartId);
    return;
  }
  if (owned.length > 1) {
    fail(
      `${at} resolves ${owned.length} candidate parts and the directive names none — ` +
        'ownership is ambiguous',
    );
  }
  assertModeMatchesArchive(entry, operation, screen, owned[0].id);
}

/**
 * Mode is part of the registry key and the archive declares it: an mcq's
 * `multipleSelection` decides radio vs checkboxes. Without this the two
 * `janus-mcq@1` entries corroborate the SAME part, so a manifest could swap
 * mode — driving and reading back the wrong interaction contract — while
 *  stayed green.
 */
function assertModeMatchesArchive(
  entry: FamilyEntry,
  operation: AnswerOperation,
  screen: RawScreen,
  partId: string,
): void {
  if (entry.partTypes.indexOf('janus-mcq') === -1) return;
  const archiveMode = mcqPartSpec(screen, partId).mode;
  if (entry.mode !== archiveMode) {
    fail(
      `screen "${screen.id}" operation "${operation.id}" declares mode "${String(entry.mode)}" ` +
        `but the archive authors part "${partId}" as ${archiveMode} ` +
        `(multipleSelection ${archiveMode === 'checkboxes'})`,
    );
  }
}

/**
 * every answer operation's family+version(+mode) resolves through the
 * registry by name, its directive passes the family's own validator, and the
 * resolved entry agrees with the raw archive's part types and widget srcs.
 */
export function validateRegistryMetadata(manifest: AdaptiveManifest, page: RawArchivePage): void {
  manifest.screens.forEach((screen) => {
    const raw = screenById(page, screen.id);
    if (!raw) fail(`screen definition "${screen.id}" does not exist in the archive`);
    const operations = answerOperations(screen);
    // a graded screen answers locally or reads a declared dependency's prior
    // state (§3.6 cross-screen) — otherwise this gate would pass VACUOUSLY on
    // a manifest that declares no operations at all
    if (screen.role === 'graded' && operations.length === 0) {
      if ((screen.dependencies ?? []).length === 0) {
        fail(
          `graded screen "${screen.id}" declares neither an answer operation nor a ` +
            'cross-screen dependency — there is no registry metadata to corroborate',
        );
      }
    }
    operations.forEach((operation) => {
      // resolution is fail-closed BY NAME — an unknown family, version or mode
      // throws here rather than falling back to a closest entry (§3.6)
      const entry = resolveFamily({
        family: operation.family,
        version: operation.version,
        mode: operation.mode,
      });
      entry.validateDirective(operation.directive);
      assertOwnedPart(entry, operation, raw as RawScreen);
    });
    // gate directives name a control the driver must operate; unchecked, a
    // manifest could claim one the archive never renders and only fail live
    gateOperations(screen).forEach((operation) => {
      const types = GATE_PART_TYPES[operation.gate];
      if (!types) fail(`screen "${screen.id}" declares unknown gate "${operation.gate}"`);
      const owned = (raw as RawScreen).parts.filter((p) => types.indexOf(p.type) !== -1);
      if (owned.length !== 1) {
        fail(
          `screen "${screen.id}" gate operation "${operation.id}" (${operation.gate}) needs ` +
            `exactly one ${types.join('|')} part, the archive renders ${owned.length}`,
        );
      }
    });
  });
}

/**
 * archive↔map↔scenario completeness against the raw archive. The
 * committed coverage gate carries bijection, route edges, endpoints, resource
 * identity, combine_feedback, correct_plan and rule-reference coverage; added
 * here are the two claims it cannot make because `ArchiveFacts` does not carry
 * parts — a navigation screen's declared button must exist in the archive, and
 * a graded screen must actually have a conditioned correct rule to grade.
 */
export function validateArchiveCoverage(manifest: AdaptiveManifest, page: RawArchivePage): void {
  validateRouteCoverage(deriveArchiveFacts(page), manifest);

  manifest.screens.forEach((screen) => {
    const raw = screenById(page, screen.id) as RawScreen;
    // role arms the oracle's graded checks — corroborate it against the archive
    // rather than trusting the manifest's own claim about itself
    const archiveRole = deriveScreenRole(raw);
    if (screen.role !== archiveRole) {
      fail(
        `screen "${screen.id}" is declared ${screen.role} but the archive derives ` +
          `${archiveRole} — a mislabelled role silently rearms or disarms the graded oracle`,
      );
    }
    if (screen.role === 'navigation') {
      const fragment = (screen.action as { src_fragment: string }).src_fragment;
      // exactly one, not "at least one": a fragment that matches several parts
      // does not identify the widget the driver is supposed to click
      const served = raw.parts.filter(
        (p) => typeof p.src === 'string' && p.src.indexOf(fragment) !== -1,
      );
      if (served.length !== 1) {
        fail(
          `navigation screen "${screen.id}" declares an in-widget button matching ` +
            `"${fragment}", which ${served.length} part srcs on that screen carry`,
        );
      }
    }
    if (screen.role === 'graded') {
      const gradable = raw.rules.some(
        (r) => !r.disabled && r.correct && r.conditions.children.length > 0,
      );
      if (!gradable) {
        fail(
          `graded screen "${screen.id}" has no enabled, conditioned correct rule in the ` +
            'archive — its verdict would not depend on the answer',
        );
      }
    }
  });
}
