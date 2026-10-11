import { expect, type Page } from '@playwright/test';
import { ScoringAttemptPO } from '@pom/dashboard/ScoringAttemptPO';
import path from 'node:path';
import { logInAs } from './session';

const scenarioPath = path.resolve(__dirname, '../scoring-queue.scenario.yaml');

/** The seeded students in queue order (newest submission first). Tables render "family, given". */
export const QUEUE = {
  PEDRO: 'Ruiz, Pedro',
  MARIA: 'Lopez, Maria',
  KEVIN: 'Student, Kevin',
  ANA: 'Alvarez, Ana',
} as const;

export type ScoringQueue = { slug: string; instructor: string };

type SeedScenario = (
  relativePath: string,
  params: Record<string, unknown>,
) => Promise<{ outputs?: unknown }>;

/** Seeds a section whose manual scoring queue holds the four students of `QUEUE`. */
export async function seedScoringQueue(seedScenario: SeedScenario): Promise<ScoringQueue> {
  const runId = `-${Date.now()}`;
  const response = await seedScenario(scenarioPath, { RUN_ID: runId });
  const outputs = response.outputs as { sections?: Record<string, string> } | undefined;
  const slug = outputs?.sections?.scoring_queue_section;

  expect(slug, 'seeded scoring queue section slug').toBeTruthy();

  return { slug: slug as string, instructor: `scoring-queue-instructor${runId}@example.com` };
}

/** Signs in as the queue's instructor and opens the first submission from the queue. */
export async function openFirstSubmission(page: Page, queue: ScoringQueue) {
  await logInAs(page, queue.instructor);

  const scoring = new ScoringAttemptPO(page);

  await scoring.openFromQueue(queue.slug, QUEUE.PEDRO);

  return { scoring, part: await scoring.selectedPart() };
}
