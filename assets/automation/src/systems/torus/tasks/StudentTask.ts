import { Page } from '@playwright/test';
import { SidebarCO } from '@pom/home/SidebarCO';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { StudentDashboardPO } from '@pom/dashboard/StudentDashboardPO';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { Waiter } from '@core/wait/Waiter';

export class StudentTask {
  private readonly sidebar: SidebarCO;
  private readonly instructorDB: InstructorDashboardPO;
  private readonly studenDN: StudentDashboardPO;
  private readonly newCS: NewCourseSetupPO;
  private readonly studentCourse: StudentCoursePO;

  constructor(private readonly page: Page) {
    this.sidebar = new SidebarCO(page);
    this.instructorDB = new InstructorDashboardPO(page);
    this.studenDN = new StudentDashboardPO(page);
    this.newCS = new NewCourseSetupPO(page);
    this.studentCourse = new StudentCoursePO(page);
  }

  async verifyCanCreateSections(textToVerify: string) {
    await this.sidebar.clickInMenu('Instructor');
    await this.instructorDB.clickCreateNewSection();
    await this.newCS.verify(textToVerify);
  }

  async searchProject(courseName: string) {
    await Waiter.waitForLoadState(this.page, 'load');
    await this.studenDN.fillSearchInput(courseName);
    await Waiter.waitForLoadState(this.page, 'load');
    await this.studenDN.enterCourse(courseName);
    await Waiter.waitForLoadState(this.page);
    await this.studentCourse.presentAssignmentBlock();
  }

  async validateResource(pageName: string) {
    await this.studentCourse.presentViewSelector();
    await this.studentCourse.presentPage(pageName);
  }
}
