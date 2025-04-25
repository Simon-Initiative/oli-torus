import fs from "fs";
import path from "path";
import { test } from "@playwright/test";
import { parse } from "csv-parse/sync";
import { TorusFacade } from "../../src/systems/torus/facade/TorusFacade";

let torus: TorusFacade;
const environment = "https://stellarator.oli.cmu.edu/";
const records = parse(
  fs.readFileSync(path.join(__dirname, "../resources", "login.csv")),
  {
    columns: true,
    skip_empty_lines: true,
  }
);

test.describe("User Accounts", () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page, environment);
    await torus.goToSite();
  });

  test.afterEach(async ({ page }) => {
    await torus.closeSite();
  });

  for (const record of records) {
    test(record.escenary, async ({ page }) => {
      await torus.login(
        record.role,
        record.pageTitle,
        record.roleVerify,
        record.welcomeTextVerify,
        record.email,
        record.password,
        record.headerVerify
      );
    });
  }
});
