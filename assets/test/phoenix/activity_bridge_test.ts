import { initActivityBridge } from '../../src/phoenix/activity_bridge';

describe('activity bridge analytics', () => {
  let analyticsTrack: jest.Mock;
  let activity: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = '<div id="bridge"><div id="activity"></div></div>';
    activity = document.getElementById('activity') as HTMLElement;
    analyticsTrack = jest.fn();
    window.TorusAnalytics = { context: {}, pageView: jest.fn(), track: analyticsTrack };
    initActivityBridge('bridge');
  });

  afterEach(() => {
    delete window.TorusAnalytics;
    delete (window as Partial<Window>).fetch;
  });

  function respond(ok: boolean, body: unknown) {
    window.fetch = jest.fn().mockResolvedValue({
      ok,
      status: ok ? 200 : 500,
      statusText: ok ? 'OK' : 'Internal Server Error',
      text: () => Promise.resolve(JSON.stringify(body)),
    } as Response);
  }

  function dispatch(name: string, activityType: unknown = 'oli_multiple_choice') {
    return new Promise<[unknown, unknown]>((resolve) => {
      activity.dispatchEvent(
        new CustomEvent(name, {
          bubbles: true,
          detail: {
            sectionSlug: 'section',
            attemptGuid: 'attempt',
            partAttemptGuid: 'part',
            payload: [],
            props: { context: { activityType } },
            continuation: (result: unknown, error: unknown) => resolve([result, error]),
          },
        }),
      );
    });
  }

  test.each([
    ['submitActivity', 'attempt_submitted'],
    ['submitPart', 'attempt_submitted'],
    ['submitEvaluations', 'attempt_submitted'],
    ['requestHint', 'hint_viewed'],
  ])('%s reports %s with the activity type after the API succeeds', async (name, event) => {
    respond(true, { type: 'success', actions: [], hint: { id: 'h1' }, hasMoreHints: true });
    const [, error] = await dispatch(name);
    expect(error).toBeUndefined();
    expect(analyticsTrack).toHaveBeenCalledTimes(1);
    expect(analyticsTrack).toHaveBeenCalledWith(event, { activity_type: 'oli_multiple_choice' });
  });

  test('failed requests and activities without a slug report nothing', async () => {
    respond(false, { message: 'failed' });
    const [, error] = await dispatch('submitActivity');
    expect(error).toBeDefined();

    respond(true, { type: 'success', hint: { id: 'h1' }, hasMoreHints: true });
    await dispatch('requestHint', null);
    expect(analyticsTrack).not.toHaveBeenCalled();
  });

  test('a successful request after the last hint is not a hint viewed', async () => {
    respond(true, { type: 'success', hasMoreHints: false });
    const [result, error] = await dispatch('requestHint');

    expect(error).toBeUndefined();
    expect(result).toEqual({ type: 'success', hasMoreHints: false });
    expect(analyticsTrack).not.toHaveBeenCalled();
  });
});
