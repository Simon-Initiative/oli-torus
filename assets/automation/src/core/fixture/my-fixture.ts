import { test as base } from '@playwright/test';
import { Utils } from '@core/Utils';

type MyFixtures = {
  utils: Utils;
};

export const test = base.extend<MyFixtures>({
  utils: async ({ page }, use) => {
    await use(new Utils(page));
  },
});
