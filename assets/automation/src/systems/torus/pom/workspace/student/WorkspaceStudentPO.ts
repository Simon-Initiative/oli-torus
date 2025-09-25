import { Page } from '@playwright/test';
import { SidebarCO } from '@pom/component/SidebarCO';

export class WorkspaceStudentPO {
  constructor(private page: Page) {}

  get sidebar() {
    return new SidebarCO(this.page);
  }
}
