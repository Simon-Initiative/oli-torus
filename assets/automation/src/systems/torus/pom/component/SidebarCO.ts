import { Locator, Page } from '@playwright/test';

export class SidebarCO {
  private readonly navbar: Locator;
  //Button minimize
  private readonly minimizeButton: Locator;
  private readonly expandButton: Locator;

  // Main workspace links
  private readonly courseAuthorLink: Locator;
  private readonly instructorLink: Locator;
  private readonly studentLink: Locator;

  // Create section
  private readonly createButton: Locator;
  private readonly objectivesLink: Locator;
  private readonly activityBankLink: Locator;
  private readonly experimentsLink: Locator;
  private readonly bibliographyLink: Locator;
  private readonly curriculumLink: Locator;
  private readonly allPagesLink: Locator;
  private readonly allActivitiesLink: Locator;

  // Publish section
  private readonly publishButton: Locator;
  private readonly reviewLink: Locator;
  private readonly publishLink: Locator;
  private readonly productsLink: Locator;

  // Improve section
  private readonly improveButton: Locator;
  private readonly insightsLink: Locator;
  private readonly datasetsLink: Locator;

  // Footer
  private readonly supportButton: Locator;
  private readonly exitProjectLink: Locator;

  // Studen section links
  private readonly studentHomeLink: Locator;
  private readonly studentLearnLink: Locator;
  private readonly studentScheduleLink: Locator;
  private readonly studentAssignmentsLink: Locator;
  private readonly studentExitCourseLink: Locator;

  constructor(page: Page) {
    this.navbar = page.locator('#desktop-workspace-nav-menu');

    //Button minimize
    this.minimizeButton = page.getByRole('button', { name: 'Minimize' });
    this.expandButton = page.getByRole('button', { name: 'Expand' });

    // Main workspace links
    this.courseAuthorLink = page.getByRole('link', { name: 'Course Author' });
    this.instructorLink = page.getByRole('link', { name: 'Instructor' });
    this.studentLink = page.getByRole('link', { name: 'Student' });

    // Create submenu
    this.createButton = this.navbar.getByRole('button', { name: 'Create' });
    this.objectivesLink = page.getByRole('link', { name: 'Objectives' });
    this.activityBankLink = page.getByRole('link', { name: 'Activity Bank' });
    this.experimentsLink = page.getByRole('link', { name: 'Experiments' });
    this.bibliographyLink = page.getByRole('link', { name: 'Bibliography' });
    this.curriculumLink = page.getByRole('link', { name: 'Curriculum' });
    this.allPagesLink = page.getByRole('link', { name: 'All Pages' });
    this.allActivitiesLink = page.getByRole('link', { name: 'All Activities' });

    // Publish submenu
    this.publishButton = page.getByRole('button', { name: 'Publish' });
    this.reviewLink = page.getByRole('link', { name: 'Review' });
    this.publishLink = page.getByRole('link', { name: 'Publish' });
    this.productsLink = page.getByRole('link', { name: 'Products' });

    // Improve submenu
    this.improveButton = page.getByRole('button', { name: 'Improve' });
    this.insightsLink = page.getByRole('link', { name: 'Insights' });
    this.datasetsLink = page.getByRole('link', { name: 'Datasets' });

    // Student section links
    this.studentHomeLink = page.getByRole('link', { name: 'Home' });
    this.studentLearnLink = page.getByRole('link', { name: 'Learn' });
    this.studentScheduleLink = page.getByRole('link', { name: 'Schedule' });
    this.studentAssignmentsLink = page.getByRole('link', { name: 'Assignments' });
    this.studentExitCourseLink = page.getByRole('link', { name: 'Exit Course' });

    // Footer
    this.supportButton = page.getByRole('button', { name: 'Support' });
    this.exitProjectLink = page.getByRole('link', { name: 'Exit Project' });
  }

  get workspace() {
    return {
      clickMinimize: async () => await this.minimizeButton.click(),
      clickExpand: async () => await this.expandButton.click(),
      clickAuthor: async () => await this.courseAuthorLink.click(),
      clickInstructor: async () => await this.instructorLink.click(),
      clickStudent: async () => await this.studentLink.click(),
    };
  }

  get author() {
    return {
      clickCreate: async () => await this.createButton.click(),
      clickObjectives: async () => await this.objectivesLink.click(),
      clickActivityBank: async () => await this.activityBankLink.click(),
      clickExperiments: async () => await this.experimentsLink.click(),
      clickBibliography: async () => await this.bibliographyLink.click(),
      clickCurriculum: async () => await this.curriculumLink.click(),
      clickAllPages: async () => await this.allPagesLink.click(),
      clickAllActivities: async () => await this.allActivitiesLink.click(),

      clickPublish: async () => await this.publishButton.click(),
      clickReview: async () => await this.reviewLink.click(),
      clickPublishLink: async () => await this.publishLink.click(),
      clickProducts: async () => await this.productsLink.click(),

      clickImprove: async () => await this.improveButton.click(),
      clickInsights: async () => await this.insightsLink.click(),
      clickDatasets: async () => await this.datasetsLink.click(),
    };
  }

  get student() {
    return {
      clickHome: async () => await this.studentHomeLink.click(),
      clickLearn: async () => await this.studentLearnLink.click(),
      clickSchedule: async () => await this.studentScheduleLink.click(),
      clickAssignments: async () => await this.studentAssignmentsLink.click(),
      clickExitCourse: async () => await this.studentExitCourseLink.click(),
    };
  }

  get footer() {
    return {
      clickSupport: async () => await this.supportButton.click(),
      clickExitProject: async () => await this.exitProjectLink.click(),
    };
  }
}
