import fs from 'node:fs';
import path from 'node:path';
import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { HomeTask } from '@tasks/HomeTask';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import {
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';

/**
 * MER-5675: Habitable Worlds Brightness - Assessment adaptive lesson.
 *
 * Imports the temporary local Habitable Worlds course archive, creates an
 * open-and-free section with a learner, and completes the 5-screen scored
 * assessment by reading the randomized star values rendered in the deck.
 *
 * Temporary local archive usage:
 *   MER_5675_ARCHIVE_PATH=/path/to/course.zip npx playwright test hw-brightness-assessment
 *
 * After this happy path is stable, the archive should move to the private
 * Playwright assets bucket and this spec can switch to fetchTestArchiveToTempFile.
 */

type StarName = 'Dargo' | 'Aeryn' | 'Crichton';

type StarValues = {
  flux: number;
  parallax: number;
};

const starNames = {
  Aeryn: ['Aeryn'],
  Crichton: ['Crichton', 'Chrichton'],
  Dargo: ['Dargo'],
} as const satisfies Record<StarName, readonly string[]>;

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const archivePath = path.resolve(
  process.env.MER_5675_ARCHIVE_PATH || '../../export_habworlds_accessible_version_w.zip',
);
const lessonTitle = 'Brightness - Assessment';
const lessonSearchTerm = 'Brightness - Assessment';
const lightYearsPerParsec = 3.26;
const metersPerLightYear = 9.4605e15;
const solarLuminosityWatts = 3.827226e26;

let seededCourse: AutomationSetupResponse | null = null;

setRuntimeConfig({
  baseUrl,
  scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
  loginData: buildAutomationLoginData('placeholder@example.com', 'placeholder'),
});

test.skip(
  !automationApiKey,
  'Set PLAYWRIGHT_AUTOMATION_API_KEY to run this test (see setup instructions above)',
);
test.skip(
  !fs.existsSync(archivePath),
  `Set MER_5675_ARCHIVE_PATH or place the temporary archive at ${archivePath}`,
);

test.describe.serial('Habitable Worlds Brightness assessment adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000);

    seededCourse = await importArchiveAndCreateSection(request, archivePath, {
      baseUrl,
      apiKey: automationApiKey!,
    });
    setRuntimeConfig({
      loginData: buildAutomationLoginData(
        seededCourse.learner.email,
        seededCourse.learner.password,
      ),
    });
  });

  test.afterAll(async ({ request }) => {
    if (!seededCourse) {
      return;
    }

    await teardownAutomationCourse(request, seededCourse, {
      baseUrl,
      apiKey: automationApiKey!,
    });
  });

  test('student completes the Brightness assessment happy path', async ({ page }) => {
    test.setTimeout(360_000);

    if (!seededCourse) {
      throw new Error('Automation setup did not produce seeded course data');
    }

    const adaptiveLesson = new AdaptiveLessonTask(page);

    await page.goto('/');
    await new HomeTask(page).login('student');
    await adaptiveLesson.openFromOutline(seededCourse.section.slug, lessonTitle, lessonSearchTerm);

    await beginTesting(page);

    const dargo = await readStarValues(page, 'Dargo');
    await fillSpinbutton(
      page,
      /Distance in light years/i,
      formatFixed(distanceInLightYears(dargo), 2),
    );
    await fillSpinbutton(page, /Distance in meters/i, formatScientific(distanceInMeters(dargo), 2));
    await submitCurrentScreen(page, { nextSpinbutton: /Luminosity in watts/i });

    const dargoDistanceMeters = distanceInMeters(dargo);
    const dargoLuminosityWatts = luminosityInWatts(dargo.flux, dargoDistanceMeters);
    await fillSpinbutton(page, /Luminosity in watts/i, formatScientific(dargoLuminosityWatts, 2));
    await fillSpinbutton(
      page,
      /Luminosity in solar/i,
      formatSolarLuminosity(wattsToSolarLuminosities(dargoLuminosityWatts)),
    );
    await submitCurrentScreen(page, { nextSpinbutton: /Luminosity of Aeryn \(LS\)/i });

    const aeryn = await readStarValues(page, 'Aeryn');
    const crichton = await readStarValues(page, 'Crichton');
    await fillSpinbutton(
      page,
      /Luminosity of Aeryn \(LS\)/i,
      formatSolarLuminosity(luminosityInSolarUnits(aeryn)),
    );
    await fillSpinbutton(
      page,
      /Luminosity of Crichton \(LS\)/i,
      formatSolarLuminosity(luminosityInSolarUnits(crichton)),
    );
    await submitCurrentScreen(page, { nextButton: /^Finish$/i });
    await finishAdaptiveLesson(page);
  });
});

async function beginTesting(page: Page) {
  await clickAdaptiveButton(page, /^Begin Testing$/i);
  await expectAdaptiveSpinbutton(page, /Distance in light years/i);
}

async function submitCurrentScreen(
  page: Page,
  expectedNext?: { nextButton?: RegExp; nextSpinbutton?: RegExp },
) {
  await clickAdaptiveButton(page, /^Submit$/i);
  await waitForExpectedAdaptiveStep(page, expectedNext);
}

async function waitForExpectedAdaptiveStep(
  page: Page,
  expectedNext?: { nextButton?: RegExp; nextSpinbutton?: RegExp },
) {
  const deadline = Date.now() + 30_000;

  while (Date.now() < deadline) {
    await waitForAdaptiveSettled(page);

    if (expectedNext?.nextSpinbutton) {
      const input = await maybeFindAdaptiveLocator(page, (scope) =>
        scope.getByRole('spinbutton', { name: expectedNext.nextSpinbutton }).first(),
      );

      if (input) {
        return;
      }
    }

    if (expectedNext?.nextButton) {
      const button = await maybeFindAdaptiveLocator(page, (scope) =>
        scope.getByRole('button', { name: expectedNext.nextButton }).last(),
      );

      if (button) {
        return;
      }
    }

    if (await requiredResponsesWarningVisible(page)) {
      throw new Error(
        `Assessment rejected the current responses as incomplete. ${await adaptiveDebug(page)}`,
      );
    }

    const nextButton = await maybeFindAdaptiveLocator(page, (scope) =>
      scope.getByRole('button', { name: /^Next$/i }).last(),
    );

    if (nextButton) {
      await nextButton.click();
    }
  }

  throw new Error(`Expected next adaptive step did not appear. ${await adaptiveDebug(page)}`);
}

async function finishAdaptiveLesson(page: Page) {
  await clickAdaptiveButton(page, /^Finish$/i);

  const finishedDialog = page.locator('.finishedDialog.modal.in').first();
  const finishedContent = page.locator('#lessonFinishedDialogContent').first();

  await expect(finishedContent).toContainText(/done|congratulations|finished/i, {
    timeout: 20_000,
  });

  const closeButton = finishedDialog
    .getByRole('button', { name: /Close feedback window/i })
    .or(
      page.locator(
        'button.close[title="Close feedback window"], button.close[aria-label="Close feedback window"]',
      ),
    )
    .first();

  if (!(await closeButton.isVisible({ timeout: 5_000 }).catch(() => false))) {
    return;
  }

  page.once('dialog', async (dialog) => {
    await dialog.accept();
  });
  await closeButton.click({ force: true });

  await expect
    .poll(
      async () => {
        const dialogStillVisible = await finishedDialog.isVisible().catch(() => false);

        return !dialogStillVisible || !page.url().includes('/adaptive_lesson/');
      },
      { message: 'Expected finished lesson dialog to close', timeout: 10_000 },
    )
    .toBe(true);
}

async function fillSpinbutton(page: Page, name: RegExp, value: string) {
  const input = await findAdaptiveLocator(page, (scope) => scope.getByRole('spinbutton', { name }));

  await input.click();
  await input.fill(value);
  await input.evaluate((element, nextValue) => {
    const inputElement = element as HTMLInputElement;
    const descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');

    descriptor?.set?.call(inputElement, nextValue);
    inputElement.dispatchEvent(new Event('input', { bubbles: true }));
    inputElement.dispatchEvent(new Event('change', { bubbles: true }));
    inputElement.blur();
  }, value);
  await expect
    .poll(
      async () => {
        const currentValue = await input.inputValue().catch(() => '');

        return currentValue.length > 0;
      },
      { message: `Expected spinbutton ${name} to keep value ${value}`, timeout: 5_000 },
    )
    .toBe(true);
  await input.press('Tab').catch(() => undefined);
  await waitForAdaptiveSettled(page);
}

async function expectAdaptiveSpinbutton(page: Page, name: RegExp) {
  const input = await findAdaptiveLocator(page, (scope) => scope.getByRole('spinbutton', { name }));

  await expect(input).toBeVisible();
}

async function clickAdaptiveButton(page: Page, name: RegExp) {
  const button = await findAdaptiveLocator(page, (scope) =>
    scope.getByRole('button', { name }).last(),
  );

  await expect(button).toBeEnabled({ timeout: 15_000 });
  await button.click();
}

async function readStarValues(page: Page, star: StarName): Promise<StarValues> {
  const text = await readStarCardText(page, star);

  return {
    parallax: parseRequiredNumber(text, /Parallax:\s*([0-9.]+)\s*"?/i, `${star} parallax`),
    flux: parseRequiredNumber(text, /Flux:\s*([0-9.]+e[+-]?\d+)\s*W\/m/i, `${star} flux`),
  };
}

async function readStarCardText(page: Page, star: StarName): Promise<string> {
  for (const scope of adaptiveScopes(page)) {
    const visibleText = await scope
      .locator('body')
      .innerText({ timeout: 2_000 })
      .catch(() => '');
    const text = starTextSegment(visibleText, star);

    if (text && /Parallax:/i.test(text) && /Flux:/i.test(text)) {
      return text;
    }
  }

  throw new Error(`Could not find the ${star} star card with parallax and flux values`);
}

function starTextSegment(visibleText: string, star: StarName) {
  for (const starAlias of starNames[star]) {
    const segment = starTextSegmentForAlias(visibleText, starAlias, star);

    if (segment) {
      return segment;
    }
  }

  return '';
}

function starTextSegmentForAlias(visibleText: string, starAlias: string, star: StarName) {
  let start = visibleText.indexOf(starAlias);

  while (start >= 0) {
    const nextStarStart = Object.entries(starNames)
      .filter(([name]) => name !== star)
      .flatMap(([, aliases]) => aliases)
      .map((alias) => visibleText.indexOf(alias, start + starAlias.length))
      .filter((index) => index > start)
      .sort((left, right) => left - right)[0];
    const segment = visibleText.slice(start, nextStarStart || start + 500);

    if (/Parallax:/i.test(segment) && /Flux:/i.test(segment)) {
      return segment;
    }

    start = visibleText.indexOf(starAlias, start + starAlias.length);
  }

  return '';
}

async function findAdaptiveLocator(
  page: Page,
  makeLocator: (scope: AdaptiveScope) => Locator,
  timeout = 20_000,
): Promise<Locator> {
  const deadline = Date.now() + timeout;

  while (Date.now() < deadline) {
    for (const scope of adaptiveScopes(page)) {
      const locator = makeLocator(scope);

      if (await locator.isVisible({ timeout: 500 }).catch(() => false)) {
        return locator;
      }
    }

    await waitForAdaptiveSettled(page);
  }

  throw new Error(`Expected adaptive locator was not found. ${await adaptiveDebug(page)}`);
}

async function maybeFindAdaptiveLocator(
  page: Page,
  makeLocator: (scope: AdaptiveScope) => Locator,
): Promise<Locator | null> {
  for (const scope of adaptiveScopes(page)) {
    const locator = makeLocator(scope);

    if (await locator.isVisible({ timeout: 500 }).catch(() => false)) {
      return locator;
    }
  }

  return null;
}

async function requiredResponsesWarningVisible(page: Page) {
  const warning = await maybeFindAdaptiveLocator(page, (scope) =>
    scope.getByText(/Responses to all questions are required to proceed/i).first(),
  );

  return warning !== null;
}

function adaptiveScopes(page: Page): AdaptiveScope[] {
  return [page.frameLocator('#adaptive_content_iframe').first(), page];
}

async function waitForAdaptiveSettled(page: Page) {
  await page.waitForLoadState('domcontentloaded').catch(() => undefined);
  await page.waitForTimeout(750);
}

async function adaptiveDebug(page: Page) {
  const visibleText = await page
    .locator('body')
    .innerText({ timeout: 1_000 })
    .catch(() => '');

  return visibleText.replace(/\s+/g, ' ').slice(0, 600);
}

function parseRequiredNumber(text: string, pattern: RegExp, label: string) {
  const match = text.match(pattern);

  if (!match) {
    throw new Error(`Could not parse ${label} from: ${text.replace(/\s+/g, ' ').slice(0, 300)}`);
  }

  return Number(match[1]);
}

function distanceInLightYears(star: StarValues) {
  return lightYearsPerParsec / star.parallax;
}

function distanceInMeters(star: StarValues) {
  return distanceInLightYears(star) * metersPerLightYear;
}

function luminosityInWatts(flux: number, distanceMeters: number) {
  return flux * 4 * Math.PI * distanceMeters ** 2;
}

function wattsToSolarLuminosities(luminosityWatts: number) {
  return luminosityWatts / solarLuminosityWatts;
}

function luminosityInSolarUnits(star: StarValues) {
  return wattsToSolarLuminosities(luminosityInWatts(star.flux, distanceInMeters(star)));
}

function formatFixed(value: number, precision: number) {
  return value.toFixed(precision);
}

function formatScientific(value: number, precision: number) {
  return value.toExponential(precision).replace('e+', 'e');
}

function formatSolarLuminosity(value: number) {
  if (value < 0.01) {
    return formatTrimmedFixed(value, 5);
  }

  if (value < 1) {
    return formatTrimmedFixed(value, 3);
  }

  return formatTrimmedFixed(value, 2);
}

function formatTrimmedFixed(value: number, precision: number) {
  return value
    .toFixed(precision)
    .replace(/(\.\d*?)0+$/, '$1')
    .replace(/\.$/, '');
}

type AdaptiveScope = Page | ReturnType<Page['frameLocator']>;
