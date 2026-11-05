import { initializeAnalytics } from '../../src/analytics';
import { track } from '../../src/analytics/track';
import { saveConsent } from '../../src/components/cookies/consent';
import { initActivityBridge } from '../../src/phoenix/activity_bridge';

const consent = {
  necessary: true,
  functionality: true,
  analytics: true,
  targeting: false,
  version: 2,
};

const context = {
  page_path: '/sections/:section_slug/lesson/:revision_slug',
  page_area: 'delivery',
  page_title: 'Learning',
  traffic_type: 'external',
  user_role: 'learner',
  course_id: 42,
  page_type: 'practice',
};

function init() {
  initializeAnalytics({
    container_id: 'GTM-QA123',
    measurement_ids: ['G-QA123'],
    consent_available: true,
    consent,
    context,
  });
}

function events() {
  return (window.dataLayer || []).filter(
    (entry): entry is Record<string, unknown> =>
      !!entry && typeof entry === 'object' && 'event' in entry,
  );
}

function scheduler(value: unknown) {
  Object.defineProperty(window, 'scheduler', { configurable: true, value });
}

describe('deferred analytics delivery', () => {
  let originalScheduler: PropertyDescriptor | undefined;
  let windowListeners: jest.SpyInstance;
  let documentListeners: jest.SpyInstance;

  beforeEach(() => {
    jest.useFakeTimers();
    originalScheduler = Object.getOwnPropertyDescriptor(window, 'scheduler');
    scheduler(undefined);
    window.sessionStorage.clear();
    delete window.TorusAnalytics;
    delete window.TorusConsentState;
    delete window.dataLayer;
    delete window.gtag;
    document.head.innerHTML = '';
    document.body.innerHTML = '';
    windowListeners = jest.spyOn(window, 'addEventListener');
    documentListeners = jest.spyOn(document, 'addEventListener');
  });

  afterEach(() => {
    for (const [type, listener, options] of windowListeners.mock.calls) {
      window.removeEventListener(type, listener, options);
    }
    for (const [type, listener, options] of documentListeners.mock.calls) {
      document.removeEventListener(type, listener, options);
    }
    if (originalScheduler) Object.defineProperty(window, 'scheduler', originalScheduler);
    else delete (window as Window & { scheduler?: unknown }).scheduler;
    delete (window as Partial<Window>).fetch;
    jest.restoreAllMocks();
    jest.clearAllTimers();
    jest.useRealTimers();
  });

  test.each([undefined, {}])('falls back to a later task with scheduler=%j', async (value) => {
    scheduler(value);
    init();
    track({ name: 'page_entered' });

    expect(events()).toEqual([]);
    expect(document.querySelector('script')).toBeNull();
    expect(Array.from(window.dataLayer![0] as IArguments).slice(0, 2)).toEqual([
      'consent',
      'default',
    ]);

    await jest.runAllTimersAsync();

    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
      'page_entered',
    ]);
    expect(document.querySelectorAll('script')).toHaveLength(1);
  });

  test('uses scheduler.yield once for a burst and waits before invoking GTM', async () => {
    let resume!: () => void;
    const yieldTask = jest.fn(() => new Promise<void>((resolve) => (resume = resolve)));
    scheduler({ yield: yieldTask });
    init();
    track({ name: 'page_entered' });
    track({ name: 'feature_used', params: { feature_name: 'outline_opened' } });

    expect(yieldTask).toHaveBeenCalledTimes(1);
    expect(jest.getTimerCount()).toBe(0);
    expect(events()).toEqual([]);

    resume();
    await jest.runAllTimersAsync();

    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
      'page_entered',
      'feature_used',
    ]);
    expect(yieldTask).toHaveBeenCalledTimes(1);
  });

  test('uses the timer fallback if scheduler.yield rejects', async () => {
    scheduler({ yield: jest.fn().mockRejectedValue(new Error('scheduler unavailable')) });
    init();
    expect(events()).toEqual([]);

    await jest.runAllTimersAsync();

    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
    ]);
  });

  test('captures event context and parameter values before navigation or caller mutation', async () => {
    init();
    const params = { activity_type: 'oli_multiple_choice' };
    track({ name: 'attempt_submitted', params });
    params.activity_type = 'oli_short_answer';
    window.TorusAnalytics!.pageView({
      ...context,
      course_id: 43,
      page_path: '/sections/:section_slug/learn',
    });
    track({ name: 'feature_used', params: { feature_name: 'notes_opened' } });

    await jest.runAllTimersAsync();

    expect(events().map((event) => [event.event, event.course_id])).toEqual([
      ['torus_page_view', 42],
      ['course_entered', 42],
      ['gtm.js', undefined],
      ['attempt_submitted', 42],
      ['torus_page_view', 43],
      ['course_entered', 43],
      ['feature_used', 43],
    ]);
    expect(events()[3].activity_type).toBe('oli_multiple_choice');
  });

  test('withdrawal immediately denies consent and cancels events and the pending loader', async () => {
    init();
    track({ name: 'attempt_submitted', params: { activity_type: 'oli_multiple_choice' } });
    await saveConsent({ ...consent, analytics: false }, { persist: false });

    expect(Array.from(window.dataLayer![window.dataLayer!.length - 1] as IArguments)).toEqual([
      'consent',
      'update',
      expect.objectContaining({ analytics_storage: 'denied' }),
    ]);
    await jest.runAllTimersAsync();
    expect(events()).toEqual([]);
    expect(document.querySelector('script')).toBeNull();
    expect(window.sessionStorage.getItem('torus_analytics_entered')).toBeNull();

    await saveConsent(consent, { persist: false });
    await jest.runAllTimersAsync();
    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
    ]);
  });

  test('reaccepting before the scheduled task cannot replay the withdrawn visit', async () => {
    init();
    track({ name: 'hint_viewed', params: { activity_type: 'oli_multiple_choice' } });
    await saveConsent({ ...consent, analytics: false }, { persist: false });
    window.TorusAnalytics!.pageView({ ...context, page_path: '/sections/:section_slug/learn' });
    await saveConsent(consent, { persist: false });
    await jest.runAllTimersAsync();

    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
    ]);
    expect(events()[0].page_path).toBe('/sections/:section_slug/learn');
  });

  test('a GTM exception cannot change a successful activity result or stop later events', async () => {
    init();
    await jest.runAllTimersAsync();
    const push = window.dataLayer!.push.bind(window.dataLayer);
    const warning = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(window.dataLayer!, 'push').mockImplementation((...entries) => {
      if ((entries[0] as { event?: string })?.event === 'attempt_submitted') {
        throw new Error('private tag failure');
      }
      return push(...entries);
    });
    document.body.innerHTML = '<div id="bridge"><div id="activity"></div></div>';
    initActivityBridge('bridge');
    window.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: () => Promise.resolve(JSON.stringify({ type: 'success', actions: [] })),
    });

    const result = await new Promise((resolve) => {
      document.getElementById('activity')!.dispatchEvent(
        new CustomEvent('submitActivity', {
          bubbles: true,
          detail: {
            sectionSlug: 'section',
            attemptGuid: 'attempt',
            payload: [],
            props: { context: { activityType: 'oli_multiple_choice' } },
            continuation: (value: unknown, error: unknown) => resolve({ value, error }),
          },
        }),
      );
    });

    expect(result).toEqual({ value: { actions: [] }, error: undefined });
    expect(warning).not.toHaveBeenCalled();
    track({ name: 'feature_used', params: { feature_name: 'outline_opened' } });
    await jest.runAllTimersAsync();
    expect(events().some((event) => event.feature_name === 'outline_opened')).toBe(true);
    expect(warning).toHaveBeenCalledWith('Analytics delivery failed; event dropped');

    track({ name: 'page_entered' });
    await jest.runAllTimersAsync();
    expect(events()[events().length - 1].event).toBe('page_entered');
  });

  test('checks consent again if it is withdrawn while GTM processes a queued event', async () => {
    init();
    await jest.runAllTimersAsync();
    const push = window.dataLayer!.push.bind(window.dataLayer);
    jest.spyOn(window.dataLayer!, 'push').mockImplementation((...entries) => {
      const result = push(...entries);
      if ((entries[0] as { event?: string })?.event === 'attempt_submitted') {
        void saveConsent({ ...consent, analytics: false }, { persist: false });
      }
      return result;
    });
    track({ name: 'attempt_submitted', params: { activity_type: 'oli_multiple_choice' } });
    track({ name: 'hint_viewed', params: { activity_type: 'oli_multiple_choice' } });

    await jest.runAllTimersAsync();

    expect(events().filter((event) => event.event === 'attempt_submitted')).toHaveLength(1);
    expect(events().filter((event) => event.event === 'hint_viewed')).toHaveLength(0);
  });

  test('yields between batches when GTM processing consumes the current task budget', async () => {
    const resumes: (() => void)[] = [];
    const yieldTask = jest.fn(() => new Promise<void>((resolve) => resumes.push(resolve)));
    scheduler({ yield: yieldTask });
    init();
    let elapsed = 0;
    jest.spyOn(performance, 'now').mockImplementation(() => elapsed);
    const push = window.dataLayer!.push.bind(window.dataLayer);
    jest.spyOn(window.dataLayer!, 'push').mockImplementation((...entries) => {
      elapsed += 100;
      return push(...entries);
    });

    resumes.shift()!();
    await jest.runAllTimersAsync();

    // Initial context and loader stay together, so consent can cancel all or none of bootstrap.
    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
    ]);
    expect(document.querySelectorAll('script')).toHaveLength(1);
    expect(yieldTask).toHaveBeenCalledTimes(1);

    track({ name: 'page_entered' });
    track({ name: 'hint_viewed', params: { activity_type: 'oli_multiple_choice' } });
    resumes.shift()!();
    await jest.runAllTimersAsync();
    expect(events()[events().length - 1].event).toBe('page_entered');
    expect(yieldTask).toHaveBeenCalledTimes(3);
    yieldTask.mockImplementation(() => Promise.resolve());
    resumes.shift()!();
    await jest.runAllTimersAsync();
    expect(events().map((event) => event.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
      'page_entered',
      'hint_viewed',
    ]);
  });
});
