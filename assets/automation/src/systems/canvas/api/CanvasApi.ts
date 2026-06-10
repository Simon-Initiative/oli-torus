export type CanvasCourse = {
  id: number;
  name: string;
  workflow_state?: string;
  html_url?: string;
};

export type CanvasModule = {
  id: number;
  name: string;
  published?: boolean;
};

export type CanvasModuleItem = {
  id: number;
  title: string;
  type: string;
  content_id?: number;
  external_url?: string;
  html_url?: string;
  new_tab?: boolean;
  published?: boolean;
};

export type CanvasEnrollment = {
  id: number;
  user_id: number;
  course_id: number;
  type: string;
  enrollment_state?: string;
};

export type CanvasLaunchCourse = {
  course: CanvasCourse;
  module: CanvasModule;
  item: CanvasModuleItem;
};

type CanvasApiParams = {
  baseUrl: string;
  token: string;
};

type CanvasApiMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

export type CreateCanvasCourseParams = CanvasApiParams & {
  accountId: string;
  courseName: string;
};

export type EnrollCanvasTeacherParams = CanvasApiParams & {
  courseId: number;
  userId: string;
};

export type CreateCanvasModuleParams = CanvasApiParams & {
  courseId: number;
  moduleName: string;
};

export type CreateCanvasExternalToolModuleItemParams = CanvasApiParams & {
  courseId: number;
  moduleId: number;
  toolName: string;
  toolLaunchUrl: string;
};

export type PublishCanvasModuleParams = CanvasApiParams & {
  courseId: number;
  moduleId: number;
};

export type PublishCanvasModuleItemParams = CanvasApiParams & {
  courseId: number;
  moduleId: number;
  itemId: number;
};

export type DeleteCanvasCourseParams = CanvasApiParams & {
  courseId: number;
};

export type CreateCanvasLaunchCourseParams = CanvasApiParams & {
  accountId: string;
  courseName: string;
  toolName: string;
  toolLaunchUrl: string;
  instructorUserId?: string;
};

export async function createCanvasCourse({
  baseUrl,
  accountId,
  token,
  courseName,
}: CreateCanvasCourseParams): Promise<CanvasCourse> {
  return canvasApiRequest<CanvasCourse>(
    baseUrl,
    token,
    'POST',
    `/api/v1/accounts/${accountId}/courses`,
    {
      'course[name]': courseName,
      'course[course_code]': courseName,
      offer: 'true',
    },
  );
}

export async function enrollCanvasTeacher({
  baseUrl,
  token,
  courseId,
  userId,
}: EnrollCanvasTeacherParams): Promise<CanvasEnrollment> {
  return canvasApiRequest<CanvasEnrollment>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${courseId}/enrollments`,
    {
      'enrollment[user_id]': userId,
      'enrollment[type]': 'TeacherEnrollment',
      'enrollment[enrollment_state]': 'active',
      'enrollment[notify]': 'false',
    },
  );
}

export async function createCanvasModule({
  baseUrl,
  token,
  courseId,
  moduleName,
}: CreateCanvasModuleParams): Promise<CanvasModule> {
  return canvasApiRequest<CanvasModule>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${courseId}/modules`,
    {
      'module[name]': moduleName,
    },
  );
}

export async function createCanvasExternalToolModuleItem({
  baseUrl,
  token,
  courseId,
  moduleId,
  toolName,
  toolLaunchUrl,
}: CreateCanvasExternalToolModuleItemParams): Promise<CanvasModuleItem> {
  return canvasApiRequest<CanvasModuleItem>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${courseId}/modules/${moduleId}/items`,
    {
      'module_item[type]': 'ExternalTool',
      'module_item[title]': toolName,
      'module_item[external_url]': toolLaunchUrl,
      'module_item[new_tab]': 'true',
    },
  );
}

export async function publishCanvasModule({
  baseUrl,
  token,
  courseId,
  moduleId,
}: PublishCanvasModuleParams): Promise<CanvasModule> {
  return canvasApiRequest<CanvasModule>(
    baseUrl,
    token,
    'PUT',
    `/api/v1/courses/${courseId}/modules/${moduleId}`,
    {
      'module[published]': 'true',
    },
  );
}

export async function publishCanvasModuleItem({
  baseUrl,
  token,
  courseId,
  moduleId,
  itemId,
}: PublishCanvasModuleItemParams): Promise<CanvasModuleItem> {
  return canvasApiRequest<CanvasModuleItem>(
    baseUrl,
    token,
    'PUT',
    `/api/v1/courses/${courseId}/modules/${moduleId}/items/${itemId}`,
    {
      'module_item[published]': 'true',
    },
  );
}

export async function createCanvasLaunchCourse({
  baseUrl,
  accountId,
  token,
  courseName,
  toolName,
  toolLaunchUrl,
  instructorUserId,
}: CreateCanvasLaunchCourseParams): Promise<CanvasLaunchCourse> {
  const course = await createCanvasCourse({
    baseUrl,
    accountId,
    token,
    courseName,
  });

  if (instructorUserId) {
    await enrollCanvasTeacher({
      baseUrl,
      token,
      courseId: course.id,
      userId: instructorUserId,
    });
  }

  let module = await createCanvasModule({
    baseUrl,
    token,
    courseId: course.id,
    moduleName: 'Torus LTI Launch',
  });

  let item = await createCanvasExternalToolModuleItem({
    baseUrl,
    token,
    courseId: course.id,
    moduleId: module.id,
    toolName,
    toolLaunchUrl,
  });

  module = await publishCanvasModule({
    baseUrl,
    token,
    courseId: course.id,
    moduleId: module.id,
  });

  item = await publishCanvasModuleItem({
    baseUrl,
    token,
    courseId: course.id,
    moduleId: module.id,
    itemId: item.id,
  });

  return { course, module, item };
}

export async function deleteCanvasCourse({ baseUrl, token, courseId }: DeleteCanvasCourseParams) {
  await canvasApiRequest<unknown>(baseUrl, token, 'DELETE', `/api/v1/courses/${courseId}`, {
    event: 'delete',
  });
}

async function canvasApiRequest<T>(
  baseUrl: string,
  token: string,
  method: CanvasApiMethod,
  path: string,
  params: Record<string, string> = {},
): Promise<T> {
  const url = new URL(path, baseUrl);
  const options: RequestInit = {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
    },
  };

  if (method === 'GET') {
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.append(key, value);
    }
  } else {
    options.headers = {
      ...options.headers,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    options.body = new URLSearchParams(params);
  }

  const response = await fetch(url, options);
  const text = await response.text();
  const body = parseCanvasResponse(text);

  if (!response.ok) {
    throw new Error(
      `${method} ${path} failed (${response.status}): ${
        typeof body === 'string' ? body : JSON.stringify(body)
      }`,
    );
  }

  return body as T;
}

function parseCanvasResponse(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}
