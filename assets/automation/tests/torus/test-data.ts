import { FileManager } from '@core/FileManager';
import { TYPE_USER } from '@pom/types/type-user';

export class TestData {
  readonly baseUrl = FileManager.getValueEnv('BASE_URL');
  readonly projectNameFilter = 'automatedtests';

  readonly loginData = {
    student: {
      type: TYPE_USER.student,
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
      type: TYPE_USER.instructor,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      email: FileManager.getValueEnv('EMAIL_INSTRUCTOR'),
      pass: FileManager.getValueEnv('PASS_INSTRUCTOR'),
      header: 'Instructor Dashboard',
    },
    author: {
      type: TYPE_USER.author,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: FileManager.getValueEnv('EMAIL_AUTHOR'),
      pass: FileManager.getValueEnv('PASS_AUTHOR'),
      header: 'Course Author',
    },
    administrator: {
      type: TYPE_USER.administrator,
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
    projectNames: [
      'TQA-10-automation',
      'TQA-11-automation',
      'TQA-12-automation',
      'TQA-13-automation',
      'TQA-14-automation',
      'TQA-15-automation',
      'TQA-17-automation',
    ],
    multiMediaFilesUpload: [
      { projectName: 'TQA-12-automation', fileName: 'img-mock-05-16-2025.jpg', type: 'image' },
      { projectName: 'TQA-13-automation', fileName: 'img-mock-05-16-2025.jpg', type: 'image' },
      { projectName: 'TQA-13-automation', fileName: 'audio-test-01.mp3', type: 'audio' },
      { projectName: 'TQA-13-automation', fileName: 'video-test-01.mp4', type: 'video' },
    ],
  };

  readonly bibliography = {
    projectName: 'TQA-13-automation',
    bibtext:
      '@book{Newton2015Philosophiae,address = {Garsington, England},author = {Newton, Isaac},year = {2015},month = {5},publisher = {Benediction Classics},title = {Philosophiae {Naturalis} {Principia} {Mathematica} ({Latin},1687)},}',
  };
}
