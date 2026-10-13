import { PageContext, initializeAnalytics } from '../../src/analytics';

const initialContext: PageContext = {
  page_path: '/sections/:section_slug/lesson/:revision_slug',
  page_area: 'delivery',
  page_title: 'Private course title',
  traffic_type: 'external',
};

describe('analytics', () => {
  let listeners: jest.SpyInstance;

  beforeEach(() => {
    delete window.TorusAnalytics;
    delete window.dataLayer;
    delete window.gtag;
    document.head.innerHTML = '';
    listeners = jest.spyOn(window, 'addEventListener');
  });

  afterEach(() => {
    for (const [type, listener] of listeners.mock.calls) {
      window.removeEventListener(type, listener);
    }
    jest.restoreAllMocks();
  });

  function pageViews() {
    return (window.dataLayer || []).filter(
      (entry) => (entry as { event?: string }).event === 'torus_page_view',
    );
  }

  test('disabled and malformed configuration creates no queue or Google script', () => {
    for (const config of [
      undefined,
      null,
      true,
      42,
      'GTM-QA123',
      [],
      {},
      { container_id: 'G-INVALID', context: initialContext },
      { container_id: ['GTM-QA123'], context: initialContext },
      { container_id: 'GTM-QA123' },
      { container_id: 'GTM-QA123', context: null },
      { container_id: 'GTM-QA123', context: { ...initialContext, page_area: ['delivery'] } },
      { container_id: 'GTM-QA123', context: initialContext, auth: 'auth' },
      { container_id: 'GTM-QA123', context: initialContext, preview: 'env-2' },
      { container_id: 'GTM-QA123', context: initialContext, auth: 123, preview: 'env-2' },
      { container_id: 'GTM-QA123', context: initialContext, auth: 'auth', preview: true },
    ]) {
      expect(() => initializeAnalytics(config)).not.toThrow();
    }
    expect(window.dataLayer).toBeUndefined();
    expect(window.gtag).toBeUndefined();
    expect(document.querySelectorAll('script')).toHaveLength(0);
  });

  test.each(['{', 'null', '42', '[]'])(
    'invalid embedded JSON %s safely disables analytics',
    (config) => {
      const script = document.createElement('script');
      script.dataset.config = config;
      jest.spyOn(document, 'currentScript', 'get').mockReturnValue(script);

      expect(() => {
        jest.isolateModules(() => {
          require('../../src/analytics/bootstrap');
        });
      }).not.toThrow();
      expect(window.dataLayer).toBeUndefined();
      expect(window.TorusAnalytics).toBeUndefined();
      expect(document.querySelectorAll('script')).toHaveLength(0);
    },
  );

  test('valid embedded configuration initializes analytics with nullable environment settings', () => {
    const script = document.createElement('script');
    script.dataset.config = JSON.stringify({
      container_id: 'GTM-QA123',
      auth: null,
      preview: null,
      context: initialContext,
    });
    jest.spyOn(document, 'currentScript', 'get').mockReturnValue(script);

    jest.isolateModules(() => {
      require('../../src/analytics/bootstrap');
    });

    expect(pageViews()).toHaveLength(1);
    expect(window.TorusAnalytics!.pagePath).toBe(initialContext.page_path);
    expect(document.querySelectorAll('script')).toHaveLength(1);
  });

  test('consent and one sanitized page view precede the async loader, which loads once', () => {
    const append = jest.spyOn(document.head, 'appendChild');
    append.mockImplementation((node) => {
      const commands = window.dataLayer!;
      expect(Array.from(commands[0] as IArguments)).toEqual([
        'consent',
        'default',
        {
          analytics_storage: 'denied',
          ad_storage: 'denied',
          ad_user_data: 'denied',
          ad_personalization: 'denied',
        },
      ]);
      expect(pageViews()).toHaveLength(1);
      return node;
    });

    initializeAnalytics({ container_id: 'GTM-QA123', context: initialContext });
    initializeAnalytics({ container_id: 'GTM-QA123', context: initialContext });
    expect(append).toHaveBeenCalledTimes(1);
    const loader = append.mock.calls[0][0] as HTMLScriptElement;
    expect(loader.src).toBe('https://www.googletagmanager.com/gtm.js?id=GTM-QA123');
    expect(loader.async).toBe(true);
    expect(loader.referrerPolicy).toBe('no-referrer');
    expect(pageViews()).toEqual([
      {
        event: 'torus_page_view',
        ...initialContext,
        page_title: 'Learning',
        page_location: window.location.origin + initialContext.page_path,
        page_referrer: '',
      },
    ]);
  });

  test('new LiveView routes count once; duplicate mounts and patch/history events do not count', () => {
    initializeAnalytics({ container_id: 'GTM-QA123', context: initialContext });
    const nextContext = { ...initialContext, page_path: '/sections/:section_slug' };
    window.dispatchEvent(new CustomEvent('phx:analytics:page_view', { detail: initialContext }));
    window.dispatchEvent(new CustomEvent('phx:navigate', { detail: { patch: true } }));
    window.dispatchEvent(new PopStateEvent('popstate'));
    expect(pageViews()).toHaveLength(1);
    for (let i = 0; i < 2; i++) {
      window.dispatchEvent(new CustomEvent('phx:analytics:page_view', { detail: nextContext }));
    }
    expect(pageViews()).toHaveLength(2);
    window.dispatchEvent(new CustomEvent('phx:analytics:page_view', { detail: initialContext }));
    expect(pageViews()).toHaveLength(3);
    expect(document.querySelectorAll('script')).toHaveLength(1);
  });

  test('rejects raw URLs and queries and discards private extras, titles and referrers', () => {
    const title = jest.spyOn(document, 'title', 'get').mockImplementation(() => {
      throw new Error('document.title must never be read');
    });
    initializeAnalytics({ container_id: 'GTM-QA123', context: initialContext });
    for (const page_path of ['https://private.example/path', '/path?secret=token', '/path#token']) {
      window.TorusAnalytics!.pageView({ ...initialContext, page_path });
    }
    expect(pageViews()).toHaveLength(1);
    window.TorusAnalytics!.pageView({
      page_path: '/users/reset_password/:token',
      page_area: 'public',
      page_title: 'Private title',
      page_location: 'https://private.example/token',
      page_referrer: 'https://lms.example/private',
      token: 'private',
      traffic_type: 'internal',
    });
    expect(pageViews()[1]).toEqual({
      event: 'torus_page_view',
      page_path: '/users/reset_password/:token',
      page_area: 'public',
      page_title: 'Torus',
      page_location: window.location.origin + '/users/reset_password/:token',
      page_referrer: '',
      traffic_type: 'internal',
    });
    expect(title).not.toHaveBeenCalled();
    expect(JSON.stringify(window.dataLayer)).not.toMatch(/Private|private\.example|lms\.example/);
  });

  test('QA environment settings are encoded on the container request', () => {
    initializeAnalytics({
      container_id: 'GTM-QA123',
      auth: 'qa_auth-123',
      preview: 'env-2',
      context: initialContext,
    });
    const loader = document.querySelector('script')!;
    const url = new URL(loader.src);
    expect(url.searchParams.get('gtm_auth')).toBe('qa_auth-123');
    expect(url.searchParams.get('gtm_preview')).toBe('env-2');
    expect(url.searchParams.get('gtm_cookies_win')).toBe('x');
    expect(document.querySelector('noscript, iframe')).toBeNull();
  });
});
