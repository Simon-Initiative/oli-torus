import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER } from '@pom/types/type-user';
import { mixedWorkflowActions } from './mixed_workflow/actions';

const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';

const configureWorkflowRun = (runId: string) =>
  setRuntimeConfig({
  baseUrl,
  scenarioToken: 'my-token',
  loginData: {
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Jane',
      email: `student${runId}@example.com`,
      name: 'Jane',
      last_name: 'Student',
      pass: defaultPassword,
    },
    instructor: {
      type: TYPE_USER.instructor,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      email: `instructor${runId}@example.com`,
      pass: defaultPassword,
      header: 'Instructor Dashboard',
    },
    author: {
      type: TYPE_USER.author,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `author${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
    administrator: {
      type: TYPE_USER.administrator,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `admin${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
  },
  });

const workflowParams = () => {
  const runId = `-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  configureWorkflowRun(runId);
  return { RUN_ID: runId };
};

test.describe('MIXED workflow', () => {
  test.setTimeout(90_000);

  test.describe('CORE', () => {
    test('CORE-A: typing text persists to author preview and delivery', async ({ runWorkflow }) => {
      await runWorkflow('./mixed_workflow/core.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('INLINE', () => {
    test('INLINE-C/D/E/I/J/K/L/M/S/T: formatting persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/inline-formatting.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });

    test('INLINE-F: internal course link persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/inline-internal-link.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });

    test('INLINE-G: external link persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/inline-external-link.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });

    test('INLINE-N: foreign text persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/inline-foreign.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });

    test('INLINE-O: popup content persists to author preview and delivery', async ({ runWorkflow }) => {
      await runWorkflow('./mixed_workflow/inline-popup.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });

    test('INLINE-R: inline callout persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/inline-callout.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('LIST', () => {
    test('LIST-C/D: circle bullet style and indentation persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/list-formatting.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('CODEBLOCK', () => {
    test('CODEBLOCK-B/C: Python language and formatted source persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/codeblock.workflow.yaml', {
          actions: mixedWorkflowActions,
          params: workflowParams(),
      });
    });
  });

  test.describe('CALLOUT', () => {
    test('CALLOUT-A: block callout text persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/callout.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });
});
