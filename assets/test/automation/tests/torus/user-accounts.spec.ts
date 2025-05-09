import { test } from "@playwright/test";
import { TorusFacade } from "../../src/systems/torus/facade/TorusFacade";
import { FileManager } from "../../src/core/FileManager";

let torus: TorusFacade;
const emailAuthor = FileManager.getValueEnv("EMAIL_AUTHOR");
const passAuthor = FileManager.getValueEnv("PASS_AUTHOR");
const emailStuden = FileManager.getValueEnv("EMAIL_STUDENT");
const passStudent = FileManager.getValueEnv("PASS_STUDENT");
const emailInstructor = FileManager.getValueEnv("EMAIL_INSTRUCTOR");
const passInstructor = FileManager.getValueEnv("PASS_INSTRUCTOR");

test.describe("User Accounts", () => {
  test.beforeEach(async ({ page }) => {
    torus = new TorusFacade(page);
    await torus.goToSite();
  });

  test.afterEach(async () => {
    await torus.closeSite();
  });

  test("TQA-2", async () => {
    await torus.login("author", "OLI Torus", "Course Author", "Welcome to OLI Torus", emailAuthor, passAuthor, "Course Author");
  });

  test("TQA-4", async () => {
    await torus.login("student", "OLI Torus", "Student", "Welcome to OLI Torus", emailStuden, passStudent, "Victoria Student");
  });

  test("TQA-5", async () => {
    await torus.login(
      "instructor",
      "Sign in",
      "Instructor",
      "Welcome to OLI Torus",
      emailInstructor,
      passInstructor,
      "Instructor Dashboard"
    );
  });
});
