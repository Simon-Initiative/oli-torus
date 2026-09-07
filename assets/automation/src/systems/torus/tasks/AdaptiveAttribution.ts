import { FenceStamp, JournalRecord, JournalSnapshot } from '@tasks/AdaptiveJournal';

/**
 * A screen visit as the driver stamped it: `entrySeq` is the fence the
 * JOURNAL issued at identity read (same seq domain as the traffic, so a
 * request racing the identity read has one strict order), and
 * `renderedAttemptGuid` roots the visit's attempt lineage.
 */
export type VisitStamp = {
  screenId: string;
  entrySeq: number;
  renderedAttemptGuid: string;
};

export type AttributedRecord = {
  record: JournalRecord;
  /** index into `visits`, or null when no visit owns the record */
  ownerIndex: number | null;
  ownerScreenId: string | null;
  /** landed in `[journalStart, entrySeq(first))` — owned by the first visit */
  preEntry: boolean;
  /** evaluations only: guid proven in the owner's attempt lineage */
  lineage: 'ok' | 'violation' | null;
};

/** Redacted by construction: guids, paths, seqs, kinds — never answer values. */
export type AttributionViolation = {
  kind: 'lineage';
  screenId: string;
  attemptGuid: string;
  requestSeq: number;
};

export type AttributionResult = {
  attributed: AttributedRecord[];
  violations: AttributionViolation[];
};

/**
 * Pure ownership reducer (spec §3.3). Ownership is by WINDOW + lineage —
 * never by payload prefixes: screen S owns `[entryStamp(S), entryStamp(S+1))`,
 * the pre-entry window belongs to the first visit, and everything after the
 * last stamp belongs to the last visit. An owned evaluation whose attempt
 * guid is not the visit's rendered attempt — nor reachable from it through
 * causally-ordered journal-observed mints — is a lineage violation, not
 * silently owned. Payload provenance is a separate judgement
 * (`resolveProvenance`), applied to owned evaluations by the oracle.
 */
export function attribute(snapshot: JournalSnapshot, visits: VisitStamp[]): AttributionResult {
  validateVisits(snapshot.fences, visits);

  const attributed: AttributedRecord[] = [];
  const violations: AttributionViolation[] = [];

  for (const record of snapshot.records) {
    const ownerIndex = owningVisit(visits, record.requestSeq);
    const owner = ownerIndex === null ? null : visits[ownerIndex];
    const preEntry =
      ownerIndex === 0 && visits.length > 0 && record.requestSeq < visits[0].entrySeq;

    let lineage: 'ok' | 'violation' | null = null;
    if (owner !== null && record.resolution === 'evaluation' && record.attemptGuid !== null) {
      const proven = guidInLineage(
        snapshot.records,
        owner.renderedAttemptGuid,
        record.attemptGuid,
        record.requestSeq,
      );
      lineage = proven ? 'ok' : 'violation';
      if (!proven) {
        violations.push({
          kind: 'lineage',
          screenId: owner.screenId,
          attemptGuid: record.attemptGuid,
          requestSeq: record.requestSeq,
        });
      }
    }

    attributed.push({
      record,
      ownerIndex,
      ownerScreenId: owner?.screenId ?? null,
      preEntry,
      lineage,
    });
  }

  return { attributed, violations };
}

/**
 * Attempt lineage, precisely (spec §3.3): the rendered attempt, extended only
 * by mints — each a parsed 2xx POST creation whose response supplied the new
 * guid and whose responseSeq precedes the requestSeq of the evaluation using
 * it — recursively rooted at the rendered attempt. A failed, unparsed, or
 * temporally later creation confers nothing. Rooting is CAUSAL, not
 * graph-closure: a mint extends the lineage only if its target had already
 * entered the lineage before the mint's own request started — an edge minted
 * before its parent attempt existed can never be retroactively rooted.
 */
function guidInLineage(
  records: readonly JournalRecord[],
  renderedGuid: string,
  candidateGuid: string,
  usedAtRequestSeq: number,
): boolean {
  if (candidateGuid === renderedGuid) return true;
  const mints = records
    .filter(
      (r) =>
        r.wireClass === 'creation' &&
        r.terminal === 'completed' &&
        r.mintedGuid !== null &&
        r.attemptGuid !== null &&
        r.status !== null &&
        r.status >= 200 &&
        r.status < 300 &&
        r.responseSeq !== null &&
        r.responseSeq < usedAtRequestSeq,
    )
    .sort((a, b) => (a.responseSeq as number) - (b.responseSeq as number));
  // guid -> seq at which it entered the lineage; the rendered attempt
  // predates every journal event
  const entered = new Map<string, number>([[renderedGuid, 0]]);
  for (const mint of mints) {
    const parentEnteredAt = entered.get(mint.attemptGuid as string);
    if (parentEnteredAt === undefined || parentEnteredAt >= mint.requestSeq) continue;
    if (!entered.has(mint.mintedGuid as string)) {
      entered.set(mint.mintedGuid as string, mint.responseSeq as number);
    }
  }
  return entered.has(candidateGuid);
}

function owningVisit(visits: VisitStamp[], requestSeq: number): number | null {
  if (visits.length === 0) return null;
  if (requestSeq < visits[0].entrySeq) return 0;
  for (let i = visits.length - 1; i >= 0; i -= 1) {
    if (requestSeq >= visits[i].entrySeq) return i;
  }
  return null;
}

function validateVisits(fences: readonly FenceStamp[], visits: VisitStamp[]) {
  const bySeq = new Map(fences.map((f) => [f.seq, f.screenId]));
  visits.forEach((v, i) => {
    if (i > 0 && v.entrySeq <= visits[i - 1].entrySeq) {
      throw new Error(
        `visit stamps out of order: visits[${i}].entrySeq=${v.entrySeq} follows ${visits[i - 1].entrySeq}`,
      );
    }
    const fenceScreen = bySeq.get(v.entrySeq);
    if (fenceScreen === undefined) {
      throw new Error(`visits[${i}] ("${v.screenId}") cites no journal fence at seq ${v.entrySeq}`);
    }
    if (fenceScreen !== v.screenId) {
      throw new Error(
        `visits[${i}] ("${v.screenId}") cites the fence at seq ${v.entrySeq}, ` +
          `which the journal issued for "${fenceScreen}"`,
      );
    }
  });
}

export type ProvenanceClass = 'own' | 'dependency' | 'ancestor';

export type ProvenanceResult = {
  classified: Array<{ prefix: string; class: ProvenanceClass }>;
  /** prefixes that are contamination — includes undeclared manifest screens */
  violations: string[];
};

/**
 * Payload provenance by precedence (spec §3.3), applied to owned evaluations:
 * the owning screen's own prefix → a declared cross-screen dependency → an
 * ancestor prefix that is NOT a manifest screen → violation. A
 * manifest-screen prefix that is not a declared dependency is contamination
 * even when it is an ancestor. Deliberate strengthening over the shipped
 * manifest-ids-only filter, named in §3.5's scope statement.
 */
export function resolveProvenance(opts: {
  submittedPrefixes: string[];
  owningScreenId: string;
  declaredDependencies: readonly string[];
  ancestors: readonly string[];
  manifestScreenIds: ReadonlySet<string>;
}): ProvenanceResult {
  const classified: Array<{ prefix: string; class: ProvenanceClass }> = [];
  const violations: string[] = [];
  for (const prefix of opts.submittedPrefixes) {
    if (prefix === opts.owningScreenId) {
      classified.push({ prefix, class: 'own' });
    } else if (opts.declaredDependencies.includes(prefix)) {
      classified.push({ prefix, class: 'dependency' });
    } else if (opts.manifestScreenIds.has(prefix)) {
      violations.push(prefix);
    } else if (opts.ancestors.includes(prefix)) {
      classified.push({ prefix, class: 'ancestor' });
    } else {
      violations.push(prefix);
    }
  }
  return { classified, violations };
}

/**
 * Submitted `<sequenceId>|stage...` prefixes of a request's part paths.
 * Evaluation PUTs nest the part map under `response.input`; PATCH saves
 * inline it. Prefixes NEVER decide ownership (§3.3) — they feed provenance.
 */
export function extractSubmittedPrefixes(partInputs: unknown[] | null): string[] {
  if (!partInputs) return [];
  const ids = new Set<string>();
  for (const part of partInputs) {
    const response = (part as { response?: Record<string, unknown> | null })?.response;
    if (!response || typeof response !== 'object') continue;
    const input =
      response.input && typeof response.input === 'object'
        ? (response.input as Record<string, unknown>)
        : response;
    for (const item of Object.values(input)) {
      const entry = item as { path?: unknown } | null;
      if (entry && typeof entry.path === 'string' && entry.path.includes('|')) {
        ids.add(entry.path.split('|')[0]);
      }
    }
  }
  return Array.from(ids);
}
