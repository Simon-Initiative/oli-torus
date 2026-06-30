import { Page } from '@playwright/test';
import { SidebarCO } from '@pom/home/SidebarCO';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { StudentDashboardPO } from '@pom/dashboard/StudentDashboardPO';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { step } from '@core/decoration/step';

export class StudentTask {
  private readonly sidebar: SidebarCO;
  private readonly instructorDB: InstructorDashboardPO;
  private readonly studentDB: StudentDashboardPO;
  private readonly newCS: NewCourseSetupPO;
  private readonly studentCourse: StudentCoursePO;

  constructor(page: Page) {
    this.sidebar = new SidebarCO(page);
    this.instructorDB = new InstructorDashboardPO(page);
    this.studentDB = new StudentDashboardPO(page);
    this.newCS = new NewCourseSetupPO(page);
    this.studentCourse = new StudentCoursePO(page);
  }

  @step('Verify that you can create a section')
  async verifyCanCreateSections(textToVerify: string) {
    await this.sidebar.clickInMenu('Instructor');
    await this.instructorDB.clickCreateNewSection();
    await this.newCS.verify(textToVerify);
  }

  @step('Search project "{courseName}"')
  async searchProject(courseName: string) {
    await this.studentDB.waitForVisibleCourses();
    await this.studentDB.fillSearchInput(courseName);
    await this.studentDB.enterCourse(courseName);
    await this.studentCourse.goToCourseIfPrompted();
    await this.studentCourse.presentAssignmentBlock();
  }

  @step('Validate resource "{pageName}"')
  async validateResource(pageName: string[]) {
    await this.studentCourse.presentViewSelector();
    for (const name of pageName) {
      await this.studentCourse.presentPage(name);
    }
  }
}
