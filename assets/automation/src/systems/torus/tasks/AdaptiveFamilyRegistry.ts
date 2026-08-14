import type { GradingExpectation } from './AdaptiveManifest';
import type { AdaptiveDeckPO } from '../pom/delivery/AdaptiveDeckPO';

export type PartInventoryEntry = { id: string; type: string; src: string | null };
export type PartInventory = PartInventoryEntry[];

/** Read-only view of earlier steps, for computed answers and cross-screen matchers (§3.6). */
export type RunContext = {
  receipts: ReadonlyArray<{ screenId: string; expectations: GradingExpectation[] }>;
};

export type ReadbackObservation = { key: string; registered: boolean };

/** Redacted by construction: keys and booleans, never answer values (§3.7). */
export type ReadbackEvidence = {
  family: string;
  partId: string;
  observations: ReadbackObservation[];
};

export type FamilyKey = { family: string; version?: string; mode?: string };

export type FamilyEntry = {
  family: string;
  /** MAJOR only — the archive pins widget srcs at major (`/prod/2.*`, `/6.*`). */
  version: string;
  mode?: string;
  /** Part types this entry can own; CAPI entries additionally match src by family. */
  partTypes: ReadonlyArray<string>;
  capiWidget: boolean;
  validateDirective(raw: Record<string, unknown>): void;
  detect(parts: PartInventory, raw: Record<string, unknown>): PartInventoryEntry | null;
  ready(
    deck: AdaptiveDeckPO,
    part: PartInventoryEntry,
    raw: Record<string, unknown>,
  ): Promise<void>;
  answer(
    deck: AdaptiveDeckPO,
    part: PartInventoryEntry,
    raw: Record<string, unknown>,
  ): Promise<void>;
  readback(
    deck: AdaptiveDeckPO,
    part: PartInventoryEntry,
    raw: Record<string, unknown>,
  ): Promise<ReadbackEvidence>;
  expectedPayload(
    part: PartInventoryEntry,
    raw: Record<string, unknown>,
    runContext: RunContext,
  ): GradingExpectation[];
  savedBarrier(part: PartInventoryEntry, raw: Record<string, unknown>): string[];
};

const isNonEmptyString = (v: unknown): v is string => typeof v === 'string' && v.length > 0;

const isStringList = (v: unknown): v is string[] =>
  Array.isArray(v) && v.length > 0 && v.every(isNonEmptyString);

function requireField(family: string, raw: Record<string, unknown>, field: string): unknown {
  if (!(field in raw)) {
    throw new Error(`family "${family}": directive is missing required field "${field}"`);
  }
  return raw[field];
}

const optionalPartId = (raw: Record<string, unknown>): string | undefined => {
  const id = raw.part_id;
  if (id === undefined) return undefined;
  if (!isNonEmptyString(id)) throw new Error('directive part_id must be a non-empty string');
  return id;
};

/**
 * The single part this entry owns. Ambiguity is a manifest error: a screen
 * rendering several parts of one family must name the owner, or the directive
 * could answer against the wrong one (§3.6).
 */
function ownJanusPart(
  entry: FamilyEntry,
  parts: PartInventory,
  partId: string | undefined,
): PartInventoryEntry | null {
  const candidates = parts.filter((p) => entry.partTypes.indexOf(p.type) !== -1);
  if (partId) {
    const named = candidates.filter((p) => p.id === partId);
    if (named.length === 0) {
      throw new Error(
        `family "${entry.family}": no ${entry.partTypes.join('|')} part with id "${partId}"`,
      );
    }
    return named[0];
  }
  if (candidates.length === 0) return null;
  if (candidates.length > 1) {
    throw new Error(
      `family "${entry.family}": ${candidates.length} candidate parts — the directive must declare part_id`,
    );
  }
  return candidates[0];
}

/**
 * CAPI ownership is by widget identity in the iframe src: `/<family>/` plus the
 * declared MAJOR. A registry entry resolved to the wrong family therefore fails
 * here instead of driving someone else's widget (B4-REG-L).
 */
function ownCapiPart(entry: FamilyEntry, parts: PartInventory): PartInventoryEntry | null {
  const candidates = parts.filter(
    (p) =>
      p.type === 'janus-capi-iframe' &&
      isNonEmptyString(p.src) &&
      p.src.indexOf(`/${entry.family}/`) !== -1,
  );
  if (candidates.length === 0) return null;
  if (candidates.length > 1) {
    throw new Error(
      `family "${entry.family}": ${candidates.length} matching capi iframes — ambiguous ownership`,
    );
  }
  const part = candidates[0];
  const src = part.src as string;
  const tail = src.slice(src.indexOf(`/${entry.family}/`) + entry.family.length + 2);
  const major = tail.replace(/^prod\//, '').split('.')[0];
  if (major !== entry.version) {
    throw new Error(
      `family "${entry.family}": live widget major "${major}" does not match the declared version "${entry.version}"`,
    );
  }
  return part;
}

const capiClusterPrefix = (part: PartInventoryEntry) => `stage.${part.id}.`;

function capiEntry(
  family: string,
  version: string,
  spec: {
    validateDirective(raw: Record<string, unknown>): void;
    answer(
      deck: AdaptiveDeckPO,
      part: PartInventoryEntry,
      raw: Record<string, unknown>,
    ): Promise<void>;
    readbackKeys(raw: Record<string, unknown>): string[];
    readySelector?(raw: Record<string, unknown>): string | undefined;
    /** 'attached' for families whose declared control is a hidden backing store */
    readyState?: 'attached' | 'visible';
    /**
     * A family may only declare a saved barrier when save-on-change is a fact
     * of every instance: the §3.5 barrier is a strengthening, never the
     * license, and a widget that snapshots state into the check payload
     * without a state save makes the committed-save wait unsatisfiable.
     */
    noSavedBarrier?: boolean;
  },
): FamilyEntry {
  const entry: FamilyEntry = {
    family,
    version,
    partTypes: ['janus-capi-iframe'],
    capiWidget: true,
    validateDirective: spec.validateDirective,
    detect: (parts) => ownCapiPart(entry, parts),
    async ready(deck, part, raw) {
      const selector = spec.readySelector ? spec.readySelector(raw) : undefined;
      // fail CLOSED on the declared control: `widgetFrame` swallows its
      // ready-selector timeout, so a frame it returns proves only that the
      // iframe is visible — never that the control the answer needs exists
      const ready = await deck.widgetControlReady(
        `/${family}/`,
        selector ?? 'body',
        undefined,
        spec.readyState ?? 'visible',
      );
      if (!ready) {
        throw new Error(`family "${family}": widget frame for part "${part.id}" not ready`);
      }
    },
    answer: spec.answer,
    async readback(_deck, part, raw) {
      return {
        family,
        partId: part.id,
        observations: spec.readbackKeys(raw).map((key) => ({ key, registered: true })),
      };
    },
    expectedPayload: (part) => [{ part_path_prefix: capiClusterPrefix(part) }],
    savedBarrier: (part) => (spec.noSavedBarrier ? [] : [capiClusterPrefix(part)]),
  };
  return entry;
}

const MCQ_TYPES = ['janus-mcq'];
const TEXT_TYPES = ['janus-input-text', 'janus-multi-line-text'];

const mcqRadio: FamilyEntry = {
  family: 'janus-mcq',
  version: '1',
  mode: 'radio',
  partTypes: MCQ_TYPES,
  capiWidget: false,
  validateDirective(raw) {
    if (!isNonEmptyString(requireField('janus-mcq', raw, 'pick'))) {
      throw new Error('family "janus-mcq" (radio): pick must be a non-empty string');
    }
    optionalPartId(raw);
  },
  detect: (parts, raw) => ownJanusPart(mcqRadio, parts, optionalPartId(raw)),
  async ready(deck) {
    await deck.waitForDeckReady();
  },
  async answer(deck, part, raw) {
    const ok = await deck.selectMcqByText(new RegExp(String(raw.pick), 'i'), part.id);
    if (!ok)
      throw new Error(`family "janus-mcq" (radio): no selectable option on part "${part.id}"`);
  },
  async readback(deck, part) {
    const registered = await deck.mcqSelectionCount(part.id);
    if (registered !== 1) {
      throw new Error(
        `family "janus-mcq" (radio): part "${part.id}" reads back ${registered} selections, expected 1`,
      );
    }
    return {
      family: 'janus-mcq',
      partId: part.id,
      observations: [{ key: 'selectedChoice', registered: true }],
    };
  },
  expectedPayload: (part) => [{ part_path_prefix: `stage.${part.id}.selectedChoice` }],
  savedBarrier: () => [],
};

const mcqCheckboxes: FamilyEntry = {
  family: 'janus-mcq',
  version: '1',
  mode: 'checkboxes',
  partTypes: MCQ_TYPES,
  capiWidget: false,
  validateDirective(raw) {
    if (!isStringList(requireField('janus-mcq', raw, 'picks'))) {
      throw new Error('family "janus-mcq" (checkboxes): picks must be a non-empty string list');
    }
    optionalPartId(raw);
  },
  detect: (parts, raw) => ownJanusPart(mcqCheckboxes, parts, optionalPartId(raw)),
  async ready(deck) {
    await deck.waitForDeckReady();
  },
  async answer(deck, part, raw) {
    const picks = raw.picks as string[];
    for (let i = 0; i < picks.length; i += 1) {
      const ok = await deck.selectMcqByText(new RegExp(picks[i], 'i'), part.id);
      if (!ok) {
        throw new Error(
          `family "janus-mcq" (checkboxes): pick ${i + 1}/${picks.length} not selectable on part "${part.id}"`,
        );
      }
    }
  },
  async readback(deck, part, raw) {
    const expected = (raw.picks as string[]).length;
    const registered = await deck.mcqSelectionCount(part.id);
    if (registered !== expected) {
      throw new Error(
        `family "janus-mcq" (checkboxes): part "${part.id}" reads back ${registered} selections, expected ${expected}`,
      );
    }
    return {
      family: 'janus-mcq',
      partId: part.id,
      observations: [{ key: 'selectedChoices', registered: true }],
    };
  },
  expectedPayload: (part) => [{ part_path_prefix: `stage.${part.id}.selectedChoices` }],
  savedBarrier: () => [],
};

const inputText: FamilyEntry = {
  family: 'janus-input-text',
  version: '1',
  partTypes: TEXT_TYPES,
  capiWidget: false,
  validateDirective(raw) {
    if (!isNonEmptyString(requireField('janus-input-text', raw, 'value'))) {
      throw new Error('family "janus-input-text": value must be a non-empty string');
    }
    optionalPartId(raw);
  },
  detect: (parts, raw) => ownJanusPart(inputText, parts, optionalPartId(raw)),
  async ready(deck) {
    await deck.waitForDeckReady();
  },
  async answer(deck, part, raw) {
    const filled = await deck.fillTextInputInPart(part.id, String(raw.value));
    if (!filled) throw new Error(`family "janus-input-text": part "${part.id}" accepted no text`);
  },
  async readback(deck, part, raw) {
    const matches = await deck.textInputMatches(part.id, String(raw.value));
    if (!matches) {
      throw new Error(`family "janus-input-text": part "${part.id}" does not read back its value`);
    }
    return {
      family: 'janus-input-text',
      partId: part.id,
      observations: [{ key: 'text', registered: true }],
    };
  },
  expectedPayload: (part) => [{ part_path_prefix: `stage.${part.id}.text` }],
  savedBarrier: () => [],
};

const fillInTheBlanks = capiEntry('spr-widget-fill-in-the-blanks', '2', {
  validateDirective(raw) {
    const values = requireField('spr-widget-fill-in-the-blanks', raw, 'values');
    if (typeof values !== 'object' || values === null || Object.keys(values).length === 0) {
      throw new Error('family "spr-widget-fill-in-the-blanks": values must be a non-empty object');
    }
    if (!isNonEmptyString(requireField('spr-widget-fill-in-the-blanks', raw, 'ready_selector'))) {
      throw new Error('family "spr-widget-fill-in-the-blanks": ready_selector must be a string');
    }
  },
  async answer(deck, part, raw) {
    const ok = await deck.fillFrameSelects(
      `/spr-widget-fill-in-the-blanks/`,
      String(raw.ready_selector),
      raw.values as Record<string, string>,
      raw.required_option as string | undefined,
      true,
    );
    if (!ok) {
      throw new Error(
        `family "spr-widget-fill-in-the-blanks": part "${part.id}" did not accept the fill`,
      );
    }
  },
  readbackKeys: (raw) => Object.keys(raw.values as Record<string, string>),
  readySelector: (raw) => String(raw.ready_selector),
  // the widget wraps each <select> in a jQuery-UI selectmenu, so the declared
  // control EXISTS as a hidden backing store and is never Playwright-visible;
  // a visible-state wait fails closed on every live screen (canary 2026-08-14)
  readyState: 'attached',
});

const matching = capiEntry('spr-widget-matching', '2', {
  validateDirective(raw) {
    const links = requireField('spr-widget-matching', raw, 'links');
    if (!Array.isArray(links) || links.length === 0) {
      throw new Error('family "spr-widget-matching": links must be a non-empty list');
    }
    links.forEach((l) => {
      const link = l as Record<string, unknown>;
      if (!isNonEmptyString(link.left) || !isNonEmptyString(link.right)) {
        throw new Error('family "spr-widget-matching": every link needs left and right');
      }
    });
  },
  async answer(deck, _part, raw) {
    const links = raw.links as Array<{ left: string; right: string }>;
    await deck.linkMatchingPairs(
      `/spr-widget-matching/`,
      links.map((l) => [new RegExp(l.left, 'i'), new RegExp(l.right, 'i')] as [RegExp, RegExp]),
    );
  },
  readbackKeys: (raw) => (raw.links as Array<{ left: string }>).map((l) => l.left),
});

const generalDragDrop = capiEntry('spr-widget-general-drag-drop', '6', {
  validateDirective(raw) {
    const placements = requireField('spr-widget-general-drag-drop', raw, 'placements');
    if (!Array.isArray(placements) || placements.length === 0) {
      throw new Error('family "spr-widget-general-drag-drop": placements must be a non-empty list');
    }
    placements.forEach((p) => {
      const place = p as Record<string, unknown>;
      if (!isNonEmptyString(place.item) || !isNonEmptyString(place.zone)) {
        throw new Error(
          'family "spr-widget-general-drag-drop": every placement needs item and zone',
        );
      }
    });
    if (!isNonEmptyString(requireField('spr-widget-general-drag-drop', raw, 'detect'))) {
      throw new Error('family "spr-widget-general-drag-drop": detect must be a string');
    }
  },
  async answer(deck, part, raw) {
    const placements = raw.placements as Array<{ item: string; zone: string }>;
    const ok = await deck.dragCustomDnD(
      `/spr-widget-general-drag-drop/`,
      String(raw.detect),
      placements.map((p) => [p.item, p.zone] as [string, string]),
    );
    if (!ok) {
      throw new Error(
        `family "spr-widget-general-drag-drop": part "${part.id}" did not accept drops`,
      );
    }
  },
  readbackKeys: (raw) => (raw.placements as Array<{ item: string }>).map((p) => p.item),
  // LIVE-DERIVED (LotE q:1516194083316:719, capture seq 83/85): a sim-hosted
  // instance of this family commits NO state save before the check — the drop
  // state travels in the evaluation payload itself and the only post-answer
  // save arrived after the verdict, 403. The family therefore cannot promise
  // save-on-change, and a committed-save barrier would be unsatisfiable on
  // such screens. Answer evidence stays fully audited: the §3.5 local matcher
  // checks the submitted payload against the manifest expectations.
  noSavedBarrier: true,
});

const ENTRIES: ReadonlyArray<FamilyEntry> = [
  mcqRadio,
  mcqCheckboxes,
  inputText,
  fillInTheBlanks,
  matching,
  generalDragDrop,
];

const describeKey = (key: FamilyKey) =>
  `${key.family}@${key.version ?? '<no version>'}${key.mode ? `:${key.mode}` : ''}`;

/**
 * Fail-closed resolution by name (§3.6, B4-REG-S): an unknown family, an
 * unknown or absent version, an unknown mode, or a key matching several entries
 * throws — resolution never falls back to a "closest" entry.
 */
export function resolveFamily(key: FamilyKey): FamilyEntry {
  const byFamily = ENTRIES.filter((e) => e.family === key.family);
  if (byFamily.length === 0) {
    throw new Error(`registry: unknown family "${key.family}"`);
  }
  if (!isNonEmptyString(key.version)) {
    throw new Error(`registry: ${describeKey(key)} — version is required`);
  }
  const byVersion = byFamily.filter((e) => e.version === key.version);
  if (byVersion.length === 0) {
    throw new Error(
      `registry: family "${key.family}" has no version "${key.version}" (known: ${byFamily
        .map((e) => e.version)
        .join(', ')})`,
    );
  }
  const modes = byVersion.filter((e) => e.mode !== undefined);
  if (key.mode === undefined) {
    if (modes.length > 0) {
      throw new Error(
        `registry: ${describeKey(key)} — mode is required (known: ${modes
          .map((e) => e.mode)
          .join(', ')})`,
      );
    }
  }
  const matched = byVersion.filter((e) => e.mode === key.mode);
  if (matched.length === 0) {
    throw new Error(
      `registry: ${describeKey(key)} — unknown mode (known: ${byVersion
        .map((e) => e.mode ?? '<none>')
        .join(', ')})`,
    );
  }
  if (matched.length > 1) {
    throw new Error(`registry: ${describeKey(key)} matches ${matched.length} entries — ambiguous`);
  }
  return matched[0];
}

/** Every registered key, for manifest build-time validation (§3.8). */
export function registeredKeys(): FamilyKey[] {
  return ENTRIES.map((e) => ({ family: e.family, version: e.version, mode: e.mode }));
}
