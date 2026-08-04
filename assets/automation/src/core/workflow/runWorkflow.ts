import path from 'node:path';
import { seedScenarioFromFile } from '@core/seedScenario';
import { interpolateWorkflowParams } from '@core/workflow/interpolate';
import { loadWorkflowFromFile } from '@core/workflow/loadWorkflow';
import {
  RunWorkflowOptions,
  WorkflowActionContext,
  WorkflowOutputs,
  WorkflowState,
} from '@core/workflow/types';
import { getBaseUrl, getScenarioToken } from '@core/runtimeConfig';
import { test } from '@playwright/test';

export async function runWorkflowFromFile(
  workflowFilePath: string,
  options: RunWorkflowOptions,
  context: Omit<WorkflowActionContext, 'seedScenario' | 'state'>,
) {
  const absoluteWorkflowPath = path.resolve(workflowFilePath);
  const workflowDir = path.dirname(absoluteWorkflowPath);
  const workflow = loadWorkflowFromFile(absoluteWorkflowPath);
  const baseUrl = (context.testInfo.project.use.baseURL as string) || getBaseUrl();
  const state: WorkflowState = {
    params: options.params ?? {},
    steps: {},
  };

  const seedScenario = async (relativePath: string, params: Record<string, unknown> = {}) => {
    const scenarioPath = path.resolve(workflowDir, relativePath);

    return seedScenarioFromFile(context.request, scenarioPath, params, baseUrl, getScenarioToken());
  };

  for (const step of workflow.workflow) {
    if (step.scenario) {
      const resolvedParams = interpolateWorkflowParams(step.scenario.params ?? {}, state, step.id);
      const response =
        await test.step(`workflow scenario: ${step.id} (${step.scenario.file})`, async () =>
          seedScenario(step.scenario.file, resolvedParams));

      state.steps[step.id] = {
        id: step.id,
        outputs: (response.outputs as WorkflowOutputs | undefined) ?? {},
        summary: response.summary,
        type: 'scenario',
      };

      continue;
    }

    if (step.playwright_action) {
      const action = options.actions[step.playwright_action.action];

      if (!action) {
        throw new Error(
          `Workflow step "${step.id}" references unknown Playwright action "${step.playwright_action.action}"`,
        );
      }

      const resolvedParams = interpolateWorkflowParams(
        step.playwright_action.params ?? {},
        state,
        step.id,
      );

      const actionOutputs =
        await test.step(`workflow action: ${step.id} (${step.playwright_action.action})`, async () =>
          action(
            {
              ...context,
              seedScenario,
              state,
            },
            resolvedParams,
          ));

      const outputs: WorkflowOutputs = typeof actionOutputs === 'undefined' ? {} : actionOutputs;

      state.steps[step.id] = {
        id: step.id,
        outputs,
        type: 'playwright_action',
      };
    }
  }

  return state;
}
