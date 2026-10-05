import { expect, test } from '@playwright/test';
import { isSignedOutUrl } from '@core/signedOut';

const at = (path: string) => new URL(path, 'http://localhost');

test('the author login redirect counts as signed out', () => {
  expect(isSignedOutUrl(at('/authors/log_in'))).toBe(true);
});

test('the sign-out fallback landing on the home page counts as signed out', () => {
  expect(isSignedOutUrl(at('/'))).toBe(true);
});

test('pages that require a session do not count as signed out', () => {
  expect(isSignedOutUrl(at('/workspaces/course_author'))).toBe(false);
  expect(isSignedOutUrl(at('/admin/audit_log'))).toBe(false);
  expect(isSignedOutUrl(at('/admin/authors/12'))).toBe(false);
});
