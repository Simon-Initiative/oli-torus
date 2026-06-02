import { type Page } from '@playwright/test';
import { requireAnyEnv, requireEnv } from '../../../support/testConfig';

type CanvasCredentials = {
  email: string;
  password: string;
};

// Logs into Canvas with the given credentials and waits for the successful-login redirect.
export const loginToCanvas = async (page: Page, email: string, password: string) => {
  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);
};

// Reads the student credentials used by the grade passback test.
export const getCanvasStudentCredentials = (): CanvasCredentials => ({
  email: requireEnv('CANVAS_STUDENT_EMAIL'),
  password: requireEnv('CANVAS_STUDENT_PASSWORD'),
});

// Reads the instructor credentials used by the grade passback test.
export const getCanvasInstructorCredentials = (): CanvasCredentials => ({
  email: requireAnyEnv(['CANVAS_ADMIN_EMAIL', 'CANVAS_INSTRUCTOR_EMAIL']),
  password: requireAnyEnv(['CANVAS_ADMIN_PASSWORD', 'CANVAS_INSTRUCTOR_PASSWORD']),
});

// Resolves the authenticated user's display name from Canvas.
export const getCanvasUserName = async (page: Page) => {
  const user = await page.evaluate(async () => {
    const response = await fetch('/api/v1/users/self', {
      headers: { Accept: 'application/json' },
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error(
        `Failed to load Canvas user profile: ${response.status} ${response.statusText}`,
      );
    }

    return (await response.json()) as { name?: string };
  });

  if (!user.name) {
    throw new Error('Canvas user profile did not include a name');
  }

  return user.name;
};
