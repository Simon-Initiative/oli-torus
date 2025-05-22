import { test, expect } from "@playwright/test";

test("test", async ({ page }) => {
  await page.goto("https://stellarator.oli.cmu.edu/");
  await page.getByRole("button", { name: "Accept" }).click();
  await page.getByRole("link", { name: "For Course Authors" }).click();

  // En autor me logueo con credenciales de Admin
  await page
    .getByRole("textbox", { name: "Email" })
    .fill("test.aargos.a@gmail.com");
  await page.getByRole("textbox", { name: "Password" }).fill("CES2025!!!!!!");
  await page.getByRole("button", { name: "Sign in" }).click();

  // AdminMenuCO
  await page.locator("#workspace-user-menu").click();
  await page.getByRole("link", { name: " Admin Panel" }).click();

  // AdminManagmentPO
  await page.getByRole("link", { name: "Manage Students and" }).click();
  await page.waitForTimeout(2000);

  //AdminAllUsersPO
  await page
    .getByRole("textbox", { name: "Search..." })
    .fill("test.argos.s@gmail.com");
  await page.getByRole("link", { name: "Argos, Victoria Student" }).click();

  // AdminUserDetailsPO
  await page.goto("https://stellarator.oli.cmu.edu/admin/users/26407");
  await page.waitForTimeout(2000);
  await page.getByRole("button", { name: "Edit" }).click();
  await page.getByRole("checkbox", { name: "Can Create Sections" }).check();
  await page.getByRole("button", { name: "Save" }).click();

  //AdminMenuCO
  await page.locator("#user-account-menu").click();
  await page.getByRole("link", { name: "Sign out" }).click();

  //Tengo que hacer click en Oli torus para poder loguearme como estudiante
  await page.getByRole("link", { name: "OLI Torus" }).click();
  await page
    .getByRole("textbox", { name: "Email" })
    .fill("test.argos.s@gmail.com");
  await page.getByRole("textbox", { name: "Password" }).fill("CES2025!!!!!!");
  await page.getByRole("button", { name: "Sign in" }).click();

  //Tengo que seleccionar en el sidebar Instructor (ya poder verlo significa que podemos crear una nueva seccion)
  await page.getByRole("link", { name: "Instructor" }).click();

  //Verificamos que se puede hacer una nueva seccion con los permisos dados anteriormente
  await page.getByRole("link", { name: "Create New Section" }).click();
  await page.getByRole("heading", { name: "New course set up" }).click();
  await expect(page.locator("#stepper_content")).toContainText(
    "New course set up"
  );
});
