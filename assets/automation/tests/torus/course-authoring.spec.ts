import test from "@playwright/test";
import { TorusFacade } from "../../src/systems/torus/facade/TorusFacade";

const environment = "https://stellarator.oli.cmu.edu/";
const projectNameFilter = "LeoProjectAuto";
let torus: TorusFacade;

test.describe("Course authoring", () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page, environment);
    await torus.goToSite();
  });

  test.afterEach(async ({ page }) => {
    await torus.closeSite();
  });

  test("2.1", async ({ page }) => {
    await torus.login(
      "author",
      "OLI Torus",
      "Course Author",
      "Welcome to OLI Torus",
      "test.argos.auth@gmail.com",
      "CES2025!!!!!!",
      "Course Author"
    );

    const projectName = await torus.createNewProjectAsOpen(projectNameFilter);

    await torus.goToSite();
    await torus.login(
      "instructor",
      "Sign in",
      "Instructor",
      "Welcome to OLI Torus",
      "test.argos.ins@gmail.com",
      "CES2025!!!!!!",
      "Instructor Dashboard",
      false
    );

    await torus.verifyProjectAsOpen(projectName);
  });
});
