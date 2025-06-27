import { FileManager } from '@core/FileManager';
import { USER_TYPES } from '@pom/types/user-type';

export class TestData {
  readonly baseUrl = FileManager.getValueEnv('BASE_URL');
  readonly projectNameFilter = 'HHBBOO';

  readonly loginData = {
    student: {
      type: USER_TYPES.STUDENT,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      email: FileManager.getValueEnv('EMAIL_STUDENT'),
      name: FileManager.getValueEnv('NAME_STUDENT'),
      pass: FileManager.getValueEnv('PASS_STUDENT'),
    },
    intructor: {
      type: USER_TYPES.INSTRUCTOR,
      pageTitle: 'Sign in',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      email: FileManager.getValueEnv('EMAIL_INSTRUCTOR'),
      pass: FileManager.getValueEnv('PASS_INSTRUCTOR'),
      header: 'Instructor Dashboard',
    },
    author: {
      type: USER_TYPES.AUTHOR,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      email: FileManager.getValueEnv('EMAIL_AUTHOR'),
      pass: FileManager.getValueEnv('PASS_AUTHOR'),
      header: 'Course Author',
    },
    admin: {
      email: FileManager.getValueEnv('EMAIL_ADMIN'),
      pass: FileManager.getValueEnv('PASS_ADMIN'),
    },
  };
}
