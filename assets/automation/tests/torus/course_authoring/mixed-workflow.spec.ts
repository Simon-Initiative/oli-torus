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

    test('INLINE-O: popup content persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
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

  test.describe('TABLE', () => {
    test('TABLE-B/C/D/E/F: table structure and cell formatting persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/table-structure.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });

    test('TABLE-G/H: alternating rows and hidden borders persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/table-styles.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('IMAGE', () => {
    test('IMAGE-B/C/D/E/F: image replacement and settings persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/image.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('FIGURE', () => {
    test('FIGURE-B/C: title and nested content persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/figure.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('YOUTUBE', () => {
    test('YOUTUBE-B/C/D/F/G/H/I: YouTube editing and lifecycle persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/youtube.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('VIDEO', () => {
    test('VIDEO-B/C/D/E/F/G: video settings and lifecycle persist to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/video.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('WEBPAGE', () => {
    test('WEBPAGE-A/B/D: webpage editing persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/webpage.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('DIALOG', () => {
    test('DIALOG-B/C/D/E/F/G/H/I/J/K/L: dialog editing persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/dialog.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('CONJUGATION', () => {
    test('CONJUGATION-B/C/D/E/F/G/H: conjugation editing persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/conjugation.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('DEFINITION', () => {
    test('DEFINITION-B: definition editing persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/definition.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('DESCRIPTIONLIST', () => {
    test('DESCRIPTIONLIST-B/C/D/E: description list editing persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/description-list.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('THEOREM', () => {
    test('THEOREM-B: theorem editing persists to author preview and delivery', async ({
      runWorkflow,
    }) => {
      await runWorkflow('./mixed_workflow/theorem.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('FORMULA', () => {
    test('FORMULA-B: LaTeX formula persists to author preview and delivery', async ({ runWorkflow }) => {
      await runWorkflow('./mixed_workflow/formula.workflow.yaml', {
        actions: mixedWorkflowActions,
        params: workflowParams(),
      });
    });
  });

  test.describe('CODEBLOCK', () => {
    test('CODEBLOCK-B/C/D/E: Python language and formatted source survive delete/undo and persist to author preview and delivery', async ({
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
