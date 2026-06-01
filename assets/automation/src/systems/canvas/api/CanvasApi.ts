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

export async function createCanvasLaunchCourse({
  baseUrl,
  accountId,
  token,
  courseName,
  toolName,
  toolLaunchUrl,
  instructorUserId,
}: {
  baseUrl: string;
  accountId: string;
  token: string;
  courseName: string;
  toolName: string;
  toolLaunchUrl: string;
  instructorUserId?: string;
}): Promise<CanvasLaunchCourse> {
  const course = await canvasApiRequest<CanvasCourse>(
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

  if (instructorUserId) {
    await enrollCanvasTeacher({
      baseUrl,
      token,
      courseId: course.id,
      userId: instructorUserId,
    });
  }

  let module = await canvasApiRequest<CanvasModule>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${course.id}/modules`,
    {
      'module[name]': 'Torus LTI Launch',
    },
  );

  let item = await canvasApiRequest<CanvasModuleItem>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${course.id}/modules/${module.id}/items`,
    {
      'module_item[type]': 'ExternalTool',
      'module_item[title]': toolName,
      'module_item[external_url]': toolLaunchUrl,
      'module_item[new_tab]': 'true',
    },
  );

  module = await canvasApiRequest<CanvasModule>(
    baseUrl,
    token,
    'PUT',
    `/api/v1/courses/${course.id}/modules/${module.id}`,
    {
      'module[published]': 'true',
    },
  );

  item = await canvasApiRequest<CanvasModuleItem>(
    baseUrl,
    token,
    'PUT',
    `/api/v1/courses/${course.id}/modules/${module.id}/items/${item.id}`,
    {
      'module_item[published]': 'true',
    },
  );

  return { course, module, item };
}

export async function deleteCanvasCourse({
  baseUrl,
  token,
  courseId,
}: {
  baseUrl: string;
  token: string;
  courseId: number;
}) {
  await canvasApiRequest<unknown>(baseUrl, token, 'DELETE', `/api/v1/courses/${courseId}`, {
    event: 'delete',
  });
}

async function enrollCanvasTeacher({
  baseUrl,
  token,
  courseId,
  userId,
}: {
  baseUrl: string;
  token: string;
  courseId: number;
  userId: string;
}) {
  await canvasApiRequest<CanvasEnrollment>(
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

async function canvasApiRequest<T>(
  baseUrl: string,
  token: string,
  method: string,
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
