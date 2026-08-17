import { AdaptiveJournalCore } from '@tasks/AdaptiveJournal';

/**
 * B4-C4A's setup-response anchor: the frozen triple's section must equal the
 * one identity leg the rendered page cannot supply about itself. Throws BEFORE
 * the walk. A consistent BOTH-SIDES swap — correlation and finalization
 * agreeing on a foreign section — satisfies the journal's freeze binding and
 * is caught only here (W-J5). Lives OUTSIDE the driver on purpose: it is the
 * fixture's obligation, and the driver's exit inventory stays closed over the
 * driver's own source.
 */
export function assertSetupAnchor(journal: AdaptiveJournalCore, expectedSectionSlug: string): void {
  const frozen = journal.runCorrelation();
  if (frozen?.sectionSlug !== expectedSectionSlug) {
    throw new Error(
      `correlation section "${String(frozen?.sectionSlug)}" does not match the setup ` +
        `response "${expectedSectionSlug}" (B4-C4A anchor)`,
    );
  }
}

/**
 * Total over unknown thrown values (gate-B round-2 blocker 8): a promise may
 * reject with null, undefined, a string, or any object — reading `.message`
 * off it unguarded makes the CATCH the one exit that loses its evidence.
 */
export function failureText(thrown: unknown): string {
  if (thrown instanceof Error) return thrown.message;
  try {
    return `non-Error rejection: ${String(thrown)}`;
  } catch {
    return 'non-Error rejection: (unstringifiable value)';
  }
}
