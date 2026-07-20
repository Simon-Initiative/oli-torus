import { SeedScenarioResponse } from '@core/seedScenario';
import { APIRequestContext, Page, TestInfo } from '@playwright/test';
import { AdministrationTask } from '@tasks/AdministrationTask';
import { CurriculumTask } from '@tasks/CurriculumTask';
import { HomeTask } from '@tasks/HomeTask';
import { ProjectTask } from '@tasks/ProjectTask';
import { StudentTask } from '@tasks/StudentTask';

export type WorkflowScalar = string | number | boolean | null;
export type WorkflowObject = {
  [key: string]: WorkflowValue;
};

export type WorkflowValue = WorkflowScalar | WorkflowValue[] | WorkflowObject;

export type WorkflowParams = Record<string, WorkflowValue>;
export type WorkflowOutputs = Record<string, WorkflowValue>;

export type ScenarioWorkflowStep = {
  file: string;
  params?: WorkflowParams;
};

export type PlaywrightActionWorkflowStep = {
  action: string;
  params?: WorkflowParams;
};

export type WorkflowStepDefinition = {
  id: string;
  scenario?: ScenarioWorkflowStep;
  playwright_action?: PlaywrightActionWorkflowStep;
};

export type WorkflowDefinition = {
  workflow: WorkflowStepDefinition[];
};

export type WorkflowStepResult = {
  id: string;
  outputs: WorkflowOutputs;
  summary?: Record<string, unknown>;
  type: 'scenario' | 'playwright_action';
};

export type WorkflowState = {
  params: WorkflowParams;
  steps: Record<string, WorkflowStepResult>;
};

export type WorkflowActionContext = {
  administrationTask: AdministrationTask;
  curriculumTask: CurriculumTask;
  homeTask: HomeTask;
  page: Page;
  projectTask: ProjectTask;
  request: APIRequestContext;
  seedScenario: (
    relativePath: string,
    params?: Record<string, unknown>,
  ) => Promise<SeedScenarioResponse>;
  state: WorkflowState;
  studentTask: StudentTask;
  testInfo: TestInfo;
};

export type WorkflowAction = (
  context: WorkflowActionContext,
  params: WorkflowParams,
) => Promise<WorkflowOutputs | void>;

export type WorkflowActionRegistry = Record<string, WorkflowAction>;

export type RunWorkflowOptions = {
  actions: WorkflowActionRegistry;
  params?: WorkflowParams;
};
