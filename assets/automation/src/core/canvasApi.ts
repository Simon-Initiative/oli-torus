import { APIRequestContext } from '@playwright/test';

type CanvasCourse = {
  id: number;
  name: string;
  course_code: string;
};

type CanvasEnrollment = {
  id: number;
};

type CanvasTab = {
  id: string;
  label?: string;
  hidden?: boolean;
};

export class CanvasApi {
  constructor(
    private readonly request: APIRequestContext,
    private readonly baseUrl: string,
    private readonly accessToken: string,
  ) {}

  async createCourse(accountId: string, name: string, courseCode: string): Promise<CanvasCourse> {
    const response = await this.request.post(this.url(`/api/v1/accounts/${accountId}/courses`), {
      headers: this.headers(),
      form: {
        'course[name]': name,
        'course[course_code]': courseCode,
        offer: 'false',
      },
    });

    return this.parseResponse<CanvasCourse>(response, 'create Canvas course');
  }

  async enrollInstructor(courseId: number, instructorUserId: string): Promise<CanvasEnrollment> {
    const response = await this.request.post(this.url(`/api/v1/courses/${courseId}/enrollments`), {
      headers: this.headers(),
      form: {
        'enrollment[user_id]': instructorUserId,
        'enrollment[type]': 'TeacherEnrollment',
        'enrollment[enrollment_state]': 'active',
        'enrollment[notify]': 'false',
      },
    });

    return this.parseResponse<CanvasEnrollment>(response, 'enroll Canvas instructor');
  }

  async enableCourseNavigationTool(courseId: number, toolName: string) {
    const tabsResponse = await this.request.get(this.url(`/api/v1/courses/${courseId}/tabs`), {
      headers: this.headers(),
    });
    const tabs = await this.parseResponse<CanvasTab[]>(tabsResponse, 'list Canvas course tabs');
    const tab = tabs.find((candidate) => candidate.label === toolName);

    if (!tab) {
      const labels = tabs.map((candidate) => candidate.label || candidate.id).join(', ');
      throw new Error(`Canvas LTI tool tab '${toolName}' was not found. Available tabs: ${labels}`);
    }

    const updateResponse = await this.request.put(
      this.url(`/api/v1/courses/${courseId}/tabs/${encodeURIComponent(tab.id)}`),
      {
        headers: this.headers(),
        form: {
          hidden: 'false',
          position: '2',
        },
      },
    );

    await this.parseResponse<CanvasTab>(updateResponse, `enable Canvas course tab '${toolName}'`);
  }

  async deleteCourse(courseId: number) {
    const response = await this.request.delete(this.url(`/api/v1/courses/${courseId}`), {
      headers: this.headers(),
      params: {
        event: 'delete',
      },
    });

    if (!response.ok()) {
      const body = await response.text();
      console.warn(`Canvas course cleanup failed (${response.status()}): ${body}`);
    }
  }

  private url(path: string) {
    return new URL(path, this.baseUrl).toString();
  }

  private headers() {
    return {
      Authorization: `Bearer ${this.accessToken}`,
    };
  }

  private async parseResponse<T>(
    response: Awaited<ReturnType<APIRequestContext['get']>>,
    action: string,
  ): Promise<T> {
    if (!response.ok()) {
      const body = await response.text();
      throw new Error(`Failed to ${action} (${response.status()}): ${body}`);
    }

    return (await response.json()) as T;
  }
}
