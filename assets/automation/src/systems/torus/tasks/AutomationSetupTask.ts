import fs from 'node:fs/promises';
import path from 'node:path';
import { APIRequestContext } from '@playwright/test';
import { TYPE_USER } from '@pom/types/type-user';

/**
 * Thin client for the /api/v1/automation_setup|teardown endpoints, which
 * ingest a course archive and create disposable author/educator/learner
 * accounts plus an open-and-free section.
 *
 * Requires an API key with automation_setup_enabled (see api_keys table).
 */

export type AutomationSetupResponse = {
  success: boolean;
  author: { email: string; password: string };
  educator: { email: string; password: string };
  learner: { email: string; password: string };
  project: { slug: string; title: string };
  section: { slug: string };
};

type AutomationOptions = {
  baseUrl: string;
  apiKey: string;
};

export async function importArchiveAndCreateSection(
  request: APIRequestContext,
  archivePath: string,
  { baseUrl, apiKey }: AutomationOptions,
): Promise<AutomationSetupResponse> {
  // The archive is downloaded outside Playwright's traced request context first;
  // this client only reads that file back for the multipart upload.
  const archiveBuffer = await fs.readFile(path.resolve(archivePath));
  const response = await request.post(new URL('/api/v1/automation_setup', baseUrl).toString(), {
    headers: {
      Authorization: buildAutomationAuthHeader(apiKey),
    },
    multipart: {
      create_author: 'true',
      create_educator: 'true',
      create_learner: 'true',
      create_section: 'true',
      project_archive: {
        name: path.basename(archivePath),
        mimeType: 'application/zip',
        buffer: archiveBuffer,
      },
    },
    timeout: 180_000, // full course archives take a while to ingest
  });

  if (!response.ok()) {
    throw new Error(
      `automation_setup failed (${response.status()}): ${await truncatedBody(response)}`,
    );
  }

  const payload = (await response.json()) as AutomationSetupResponse;

  if (!payload.success) {
    throw new Error(`automation_setup returned unsuccessful payload: ${JSON.stringify(payload)}`);
  }

  return payload;
}

export async function teardownAutomationCourse(
  request: APIRequestContext,
  seeded: AutomationSetupResponse,
  { baseUrl, apiKey }: AutomationOptions,
) {
  const response = await request.post(new URL('/api/v1/automation_teardown', baseUrl).toString(), {
    headers: {
      Authorization: buildAutomationAuthHeader(apiKey),
    },
    data: {
      author_email: seeded.author.email,
      author_password: seeded.author.password,
      educator_email: seeded.educator.email,
      educator_password: seeded.educator.password,
      learner_email: seeded.learner.email,
      learner_password: seeded.learner.password,
      section_slug: seeded.section.slug,
      project_slug: seeded.project.slug,
    },
  });

  if (!response.ok()) {
    console.warn(
      `automation_teardown failed (${response.status()}): ${await truncatedBody(response)}`,
    );
  }
}

// dev-mode Phoenix errors are full HTML pages — keep reports readable
async function truncatedBody(response: { text(): Promise<string> }): Promise<string> {
  const body = await response.text().catch(() => '');
  return body.split('\n').slice(0, 3).join(' ').slice(0, 300);
}

function buildAutomationAuthHeader(rawKey: string) {
  return `Bearer ${Buffer.from(rawKey).toString('base64')}`;
}

export function buildAutomationLoginData(learnerEmail: string, learnerPassword: string) {
  const authorLike = (type: (typeof TYPE_USER)[keyof typeof TYPE_USER]) => ({
    type,
    pageTitle: 'OLI Torus',
    role: 'Course Author',
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle: 'Course Author',
    email: 'unused@example.com',
    pass: 'unused',
    header: 'Course Author',
  });

  return {
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Test',
      email: learnerEmail,
      name: 'Test',
      last_name: 'Learner',
      pass: learnerPassword,
    },
    instructor: {
      type: TYPE_USER.instructor,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      email: 'unused@example.com',
      pass: 'unused',
      header: 'Instructor Dashboard',
    },
    author: authorLike(TYPE_USER.author),
    administrator: authorLike(TYPE_USER.administrator),
  };
}
