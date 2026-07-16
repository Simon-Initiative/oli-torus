import fs from 'node:fs';
import path from 'node:path';
import yaml from 'js-yaml';
import { WorkflowDefinition, WorkflowStepDefinition } from '@core/workflow/types';

export function loadWorkflowFromFile(workflowFilePath: string): WorkflowDefinition {
  const absolutePath = path.resolve(workflowFilePath);
  const source = fs.readFileSync(absolutePath, 'utf8');
  const parsed = yaml.load(source);

  if (!isWorkflowDefinition(parsed)) {
    throw new Error(`Workflow file "${absolutePath}" does not define a valid workflow`);
  }

  validateWorkflow(parsed.workflow, absolutePath);
  return parsed;
}

function isWorkflowDefinition(value: unknown): value is WorkflowDefinition {
  return (
    value != null &&
    typeof value === 'object' &&
    Array.isArray((value as WorkflowDefinition).workflow)
  );
}

function validateWorkflow(workflow: WorkflowStepDefinition[], absolutePath: string) {
  const seenStepIds = new Set<string>();

  workflow.forEach((step, index) => {
    if (!step.id) {
      throw new Error(`Workflow file "${absolutePath}" is missing an id for step #${index + 1}`);
    }

    if (seenStepIds.has(step.id)) {
      throw new Error(`Workflow file "${absolutePath}" contains duplicate step id "${step.id}"`);
    }

    seenStepIds.add(step.id);

    const typeCount = Number(Boolean(step.scenario)) + Number(Boolean(step.playwright_action));

    if (typeCount !== 1) {
      throw new Error(
        `Workflow step "${step.id}" in "${absolutePath}" must declare exactly one supported step type`,
      );
    }

    if (step.scenario && !step.scenario.file) {
      throw new Error(`Workflow step "${step.id}" in "${absolutePath}" is missing scenario.file`);
    }

    if (step.playwright_action && !step.playwright_action.action) {
      throw new Error(
        `Workflow step "${step.id}" in "${absolutePath}" is missing playwright_action.action`,
      );
    }
  });
}
