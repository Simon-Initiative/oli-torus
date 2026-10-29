import { PageContext, initializeAnalytics } from '../../src/analytics';
import { track } from '../../src/analytics/track';
import { saveConsent } from '../../src/components/cookies/consent';

const consent = {
  necessary: true,
  functionality: true,
  analytics: true,
  targeting: false,
  version: 2,
};

const lesson: PageContext = {
  page_path: '/sections/:section_slug/lesson/:revision_slug',
  page_area: 'delivery',
  page_title: 'Learning',
  traffic_type: 'external',
  user_role: 'learner',
  course_id: 42,
  page_type: 'graded',
  entry_point: 'lti',
};

const eventNames = [
  'course_entered',
  'page_entered',
  'page_completed',
  'attempt_submitted',
  'hint_viewed',
  'video_started',
  'video_completed',
  'feature_used',
  'file_link_clicked',
];

function init(context: Record<string, unknown> = lesson, extra: Record<string, unknown> = {}) {
  initializeAnalytics({
    container_id: 'GTM-QA123',
    measurement_ids: ['G-QA123'],
    consent_available: true,
    consent,
    context,
    ...extra,
  });
}

function entries(): Record<string, unknown>[] {
  return (window.dataLayer || []).filter(
    (entry): entry is Record<string, unknown> =>
      !!entry && typeof entry === 'object' && !('length' in (entry as object)),
  );
}

function events(name?: string) {
  return entries().filter((entry) =>
    name ? entry.event === name : eventNames.includes(entry.event as string),
  );
}

const defined = (entry: Record<string, unknown>) =>
  Object.fromEntries(Object.entries(entry).filter(([, value]) => value !== undefined));

// Simulates a full page load in the same browser tab.
function reload() {
  delete window.TorusAnalytics;
  delete window.dataLayer;
  delete window.gtag;
}

describe('analytics events', () => {
  let windowListeners: jest.SpyInstance;
  let documentListeners: jest.SpyInstance;

  beforeEach(() => {
    window.sessionStorage.clear();
    reload();
    delete window.TorusConsentState;
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
    jest.restoreAllMocks();
  });

  test('catalogued events carry server context and only their own parameters', () => {
    init();
    track({ name: 'attempt_submitted', params: { activity_type: 'oli_multiple_choice' } });

    const [entry] = events('attempt_submitted');
    expect(defined(entry)).toEqual({
      event: 'attempt_submitted',
      user_role: 'learner',
      page_area: 'delivery',
      course_id: 42,
      page_type: 'graded',
      activity_type: 'oli_multiple_choice',
    });
  });

  test('earlier values are cleared so GTM cannot attribute them to later pushes', () => {
    init();
    track({ name: 'attempt_submitted', params: { activity_type: 'oli_multiple_choice' } });
    track({ name: 'video_started', params: { video_source: 'youtube' } });
    window.TorusAnalytics!.pageView({ ...lesson, page_path: '/sections/:section_slug/learn' });

    const [video] = events('video_started');
    const pageView = entries().filter((entry) => entry.event === 'torus_page_view')[1];
    for (const entry of [video, pageView]) {
      expect(Object.prototype.hasOwnProperty.call(entry, 'activity_type')).toBe(true);
      expect(entry.activity_type).toBeUndefined();
    }
    expect(video.video_source).toBe('youtube');
  });

  test('page views carry role, course and page type but never internal flags', () => {
    init({ ...lesson, preview_mode: undefined });
    const [pageView] = entries().filter((entry) => entry.event === 'torus_page_view');
    expect(defined(pageView)).toEqual({
      event: 'torus_page_view',
      page_path: lesson.page_path,
      page_area: 'delivery',
      page_title: 'Learning',
      traffic_type: 'external',
      user_role: 'learner',
      course_id: 42,
      page_type: 'graded',
      page_location: window.location.origin + lesson.page_path,
      page_referrer: '',
    });
  });

  test('invalid or extra context fields never reach the context or the data layer', () => {
    init({
      ...lesson,
      user_role: 'superuser',
      course_id: '42',
      page_type: 'quiz',
      entry_point: 'email',
      preview_mode: 'sneaky',
      section_id: 9876,
      user_id: 5555,
    });

    expect(window.TorusAnalytics!.context).toEqual({
      page_path: lesson.page_path,
      page_area: 'delivery',
      page_title: 'Learning',
      traffic_type: 'external',
    });
    expect(JSON.stringify(window.dataLayer)).not.toMatch(/9876|5555|superuser|quiz|sneaky/);
  });

  test('course entry counts once per tab session and course, after the page view', () => {
    init();
    expect(entries().map((entry) => entry.event)).toEqual([
      'torus_page_view',
      'course_entered',
      'gtm.js',
    ]);
    expect(defined(events('course_entered')[0])).toEqual({
      event: 'course_entered',
      user_role: 'learner',
      page_area: 'delivery',
      course_id: 42,
      entry_point: 'lti',
    });

    window.TorusAnalytics!.pageView({ ...lesson, page_path: '/sections/:section_slug/learn' });
    window.TorusAnalytics!.pageView({ ...lesson, course_id: 43 });
    expect(events('course_entered').map((entry) => entry.course_id)).toEqual([42, 43]);

    reload();
    init();
    expect(events('course_entered')).toHaveLength(0);

    for (const page_area of ['authoring', 'public']) {
      window.TorusAnalytics!.pageView({ ...lesson, page_area, course_id: 77 });
    }
    expect(events('course_entered')).toHaveLength(0);
  });

  test('without session storage, course entry counts once per page load', () => {
    jest.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    init();
    window.TorusAnalytics!.pageView({ ...lesson, page_path: '/sections/:section_slug/learn' });
    expect(events('course_entered')).toHaveLength(1);
  });

  test('nothing is sent or remembered before consent, and nothing after withdrawal', async () => {
    init(lesson, { consent: undefined });
    track({ name: 'page_entered' });
    window.dispatchEvent(
      new CustomEvent('phx:analytics:track', { detail: { name: 'page_completed' } }),
    );
    expect(events()).toHaveLength(0);
    expect(window.sessionStorage.length).toBe(0);

    await saveConsent(consent, { persist: false });
    expect(events().map((entry) => entry.event)).toEqual(['course_entered']);

    await saveConsent({ ...consent, analytics: false }, { persist: false });
    track({ name: 'hint_viewed', params: { activity_type: 'oli_short_answer' } });
    expect(events()).toHaveLength(1);
  });

  test('previews only report their launch, once per tab session', () => {
    const preview = {
      ...lesson,
      page_path: '/sections/:section_slug/preview/learn',
      user_role: 'instructor',
      preview_mode: 'preview',
    };
    init(preview);
    track({ name: 'attempt_submitted', params: { activity_type: 'oli_multiple_choice' } });
    track({ name: 'feature_used', params: { feature_name: 'dot_opened' } });
    window.TorusAnalytics!.pageView({ ...preview, page_path: '/sections/:section_slug/preview' });

    expect(events().map(defined)).toEqual([
      {
        event: 'feature_used',
        user_role: 'instructor',
        page_area: 'delivery',
        course_id: 42,
        page_type: 'graded',
        feature_name: 'preview_launched',
        feature_area: 'preview',
      },
    ]);

    window.TorusAnalytics!.pageView({
      ...lesson,
      user_role: 'author',
      preview_mode: 'template_preview',
    });
    expect(events().map((entry) => entry.feature_name)).toEqual([
      'preview_launched',
      'template_preview_launched',
    ]);
  });

  test('server pushes and bubbling JS command dispatches share one validated channel', () => {
    init();
    window.dispatchEvent(
      new CustomEvent('phx:analytics:track', {
        detail: { name: 'feature_used', params: { feature_name: 'outline_opened' } },
      }),
    );
    const button = document.body.appendChild(document.createElement('button'));
    button.dispatchEvent(
      new CustomEvent('phx:analytics:track', {
        bubbles: true,
        detail: { name: 'feature_used', params: { feature_name: 'dot_opened' } },
      }),
    );

    expect(events('feature_used').map((entry) => [entry.feature_name, entry.feature_area])).toEqual(
      [
        ['outline_opened', 'navigation'],
        ['dot_opened', 'ai_assistant'],
      ],
    );
  });

  test('uncatalogued parameters and events are dropped with a development warning', () => {
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    init();
    window.TorusAnalytics!.track('feature_used', {
      feature_name: 'notes_opened',
      user_id: 5555,
      course_id: 99,
    });
    window.TorusAnalytics!.track('page_exited', { active_time_bucket: '15m+' });

    expect(events().map((entry) => entry.event)).toEqual(['course_entered', 'feature_used']);
    expect(events('feature_used')[0].course_id).toBe(42);
    expect(warn.mock.calls.map(([message]) => message)).toEqual([
      'Analytics event feature_used dropped parameters not allowed by the catalog: course_id, user_id',
      'Dropped analytics event not in the catalog: page_exited',
    ]);
    expect(JSON.stringify(window.dataLayer)).not.toMatch(/5555/);
  });

  test('file links in lesson content report only the file type', () => {
    init(lesson, { media_url: 'https://media.torus.example/media' });
    document.body.innerHTML = `
      <div id="page_content">
        <a id="pdf" href="https://cdn.example/files/private-syllabus.PDF?token=secret"><span>Syllabus</span></a>
        <a id="media" href="https://media.torus.example/media/private-data.zip">Data</a>
        <a id="lookalike" href="https://media.torus.example/media-other/private.zip">Other</a>
        <a id="page" href="/sections/private/lesson/private-page">Next page</a>
      </div>
      <a id="outside" href="https://cdn.example/files/outside.pdf">Outside</a>`;
    // jsdom cannot navigate; the writer's capture-phase listener still runs first.
    document.addEventListener('click', (event) => event.preventDefault());

    (document.querySelector('#pdf span') as HTMLElement).click();
    for (const id of ['media', 'lookalike', 'page', 'outside']) {
      (document.getElementById(id) as HTMLElement).click();
    }

    expect(events('file_link_clicked').map(defined)).toEqual([
      {
        event: 'file_link_clicked',
        user_role: 'learner',
        page_area: 'delivery',
        course_id: 42,
        file_type: 'pdf',
      },
      {
        event: 'file_link_clicked',
        user_role: 'learner',
        page_area: 'delivery',
        course_id: 42,
        file_type: 'other',
      },
    ]);
    expect(JSON.stringify(window.dataLayer)).not.toMatch(/private|secret|media\.torus|cdn/);
  });

  test('the emitter API is a no-op when analytics is not installed', () => {
    expect(() => track({ name: 'page_entered' })).not.toThrow();
    expect(window.dataLayer).toBeUndefined();
  });
});
