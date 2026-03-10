import { getInstanceId } from '../../../src/data/persistence/trigger';

describe('getInstanceId', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('returns the legacy ai_bot instance id when present', () => {
    document.body.innerHTML = '<div id="ai_bot" data-instance-id="legacy-instance"></div>';

    expect(getInstanceId()).toBe('legacy-instance');
  });

  it('treats the rendered dialogue window as an available trigger target', () => {
    document.body.innerHTML = '<div data-dialogue-window></div>';

    expect(getInstanceId()).toBe('dialogue-window');
  });
});
