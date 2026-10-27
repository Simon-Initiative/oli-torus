import { defineConfig } from '@playwright/test';
import shared from './playwright.config';

export default defineConfig(shared, {
  reporter: [['line'], ['html', { open: 'never' }]],
  use: {
    trace: 'off',
    screenshot: 'off',
    video: 'off',
  },
});
