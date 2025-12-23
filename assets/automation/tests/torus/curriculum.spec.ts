import { test } from '@fixture/my-fixture';

const BASE_SCENARIO = './curriculum.scenario.yaml';

test.describe('Curriculum scaffold', () => {
  test('seeds project via scenario YAML', async ({ seedScenario }) => {
    const runId = `pw-${Date.now()}`;

    await seedScenario(BASE_SCENARIO, {
      run_id: runId,
      project_slug: `${runId}-project`,
    });



  });
});
