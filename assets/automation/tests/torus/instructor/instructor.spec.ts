import { test } from '@fixture/my-fixture';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { CourseManagePO } from '@pom/course/CourseManagePO';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import { Utils } from '@core/Utils';

test.describe('Instructor Dashboard', () => {
  test('Invite Students, create an invite link. Then log in as a student and paste the link in the browser. Verify the student can enroll in the course correctly', async ({
    page,
    homeTask,
  }) => {
    const cardTitle = 'HHBBOO09';
    const dashboard = new InstructorDashboardPO(page);
    const details = new CourseManagePO(page);
    const menu = new MenuDropdownCO(page);

    await homeTask.login('instructor');

    await dashboard.expectCourseToBeVisible(cardTitle);
    await dashboard.clickViewCourse(cardTitle);

    await details.verifyTitle(cardTitle);
    await details.clickOnLink('Invite Students');
    await details.clickOnButton('Section end');
    await details.verifyExpirationDate();
    await details.clickOnButton('Copy');

    await menu.signOut();
    await new Utils(page).sleep(2);
    await homeTask.login('student');
  });
});
