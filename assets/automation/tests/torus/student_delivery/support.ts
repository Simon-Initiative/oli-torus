import { type SeedScenarioResponse } from '@core/seedScenario';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER, type TypeUser } from '@pom/types/type-user';

export const baseUrl = 'http://localhost';
export const defaultPassword = 'changeme123456';
export const scenarioToken = 'my-token';

export type StudentDeliveryScenarioOutputs = {
  sections?: Record<string, string>;
};

type LoginRecordOptions = {
  emailPrefix: string;
  header?: string;
  lastName?: string;
  name?: string;
  role: string;
  type: TypeUser;
  welcomeTitle: string;
};

export function configureStudentDeliveryRuntimeConfig(
  runId: string,
  loginRecords: {
    student: LoginRecordOptions;
    instructor: LoginRecordOptions;
    author: LoginRecordOptions;
    administrator: LoginRecordOptions;
  },
) {
  setRuntimeConfig({
    baseUrl,
    scenarioToken,
    loginData: {
      student: buildLoginRecord(runId, loginRecords.student),
      instructor: buildLoginRecord(runId, loginRecords.instructor),
      author: buildLoginRecord(runId, loginRecords.author),
      administrator: buildLoginRecord(runId, loginRecords.administrator),
    },
  });
}

export function buildLoginRecord(
  runId: string,
  { type, role, emailPrefix, welcomeTitle, header, name, lastName }: LoginRecordOptions,
) {
  return {
    type: TYPE_USER[type],
    pageTitle: 'OLI Torus',
    role,
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle,
    email: `${emailPrefix}${runId}@example.com`,
    pass: defaultPassword,
    ...(header ? { header } : {}),
    ...(name ? { name } : {}),
    ...(lastName ? { last_name: lastName } : {}),
  };
}

export async function seedStudentDeliveryScenario(
  seedScenario: (
    relativePath: string,
    params?: Record<string, unknown>,
  ) => Promise<SeedScenarioResponse>,
  scenarioPath: string,
  runId: string,
): Promise<StudentDeliveryScenarioOutputs> {
  const response = await seedScenario(scenarioPath, { RUN_ID: runId });
  const outputs = response.outputs as StudentDeliveryScenarioOutputs | undefined;

  if (!outputs) {
    throw new Error('Scenario did not return outputs');
  }

  return outputs;
}
