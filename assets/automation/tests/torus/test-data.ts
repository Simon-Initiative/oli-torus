import { FileManager } from '@core/FileManager';
import { USER_TYPES } from '@pom/types/user-type';

export class TestData {
  readonly baseUrl = FileManager.getValueEnv('BASE_URL');
  readonly projectNameFilter = 'HHHBBOO';

  readonly loginData = {
    student: {
      type: USER_TYPES.STUDENT,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: `Hi, ${FileManager.getValueEnv('NAME_STUDENT')}`,
      email: FileManager.getValueEnv('EMAIL_STUDENT'),
      name: FileManager.getValueEnv('NAME_STUDENT'),
      last_name: FileManager.getValueEnv('LASTNAME_STUDENT'),
      pass: FileManager.getValueEnv('PASS_STUDENT'),
    },
    instructor: {
      type: USER_TYPES.INSTRUCTOR,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      email: FileManager.getValueEnv('EMAIL_INSTRUCTOR'),
      pass: FileManager.getValueEnv('PASS_INSTRUCTOR'),
      header: 'Instructor Dashboard',
    },
    author: {
      type: USER_TYPES.AUTHOR,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: FileManager.getValueEnv('EMAIL_AUTHOR'),
      pass: FileManager.getValueEnv('PASS_AUTHOR'),
      header: 'Course Author',
    },
    administrator: {
      type: USER_TYPES.AUTHOR,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: FileManager.getValueEnv('EMAIL_ADMIN'),
      pass: FileManager.getValueEnv('PASS_ADMIN'),
      header: 'Course Author',
    },
  };

  readonly preconditions = {
    projectNames: ['tqa12automation', 'tqa13automation', 'TQA-14-Automation', 'TQA-15-Automation'],
    multiMediaFilesUpload: [
      { projectName: 'tqa12automation', fileName: 'img-mock-05-16-2025.jpg', type: 'image' },
      { projectName: 'tqa13automation', fileName: 'img-mock-05-16-2025.jpg', type: 'image' },
      { projectName: 'tqa13automation', fileName: 'audio-test-01.mp3', type: 'audio' },
      { projectName: 'tqa13automation', fileName: 'video-test-01.mp4', type: 'video' },
    ],
  };
}
