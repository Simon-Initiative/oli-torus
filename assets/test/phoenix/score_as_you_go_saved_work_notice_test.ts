import {
  ScoreAsYouGoNavigationNotice,
  ScoreAsYouGoSavedWorkNotice,
  initializeStaticScoreAsYouGoSavedWorkNotice,
} from 'hooks/score_as_you_go_saved_work_notice';

const storageKey = 'torus.saygSavedWorkNotice';

const setLocation = (path: string) => {
  window.history.pushState({}, '', path);
};

const storedNotice = () => JSON.parse(window.sessionStorage.getItem(storageKey) || '{}');

const noticeElement = (staticNotice = false) => {
  const el = document.createElement('div');
  el.id = 'sayg_saved_work_notice';
  el.className = 'hidden';
  if (staticNotice) {
    el.dataset.saygSavedWorkStatic = 'true';
  }
  el.innerHTML = `
    <p data-sayg-saved-work-message></p>
    <button type="button" data-sayg-saved-work-dismiss>Close</button>
  `;
  document.body.appendChild(el);

  return el;
};

describe('score as you go saved work notice hooks', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    window.sessionStorage.clear();
    setLocation('/sections/example/lesson/sayg-page');
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('stores a notice before internal link navigation from a SAYG page', () => {
    const source = document.createElement('div');
    source.dataset.message = 'Your work has been saved.';

    const hook = { el: source };
    ScoreAsYouGoNavigationNotice.mounted.call(hook as any);

    const link = document.createElement('a');
    link.href = '/sections/example/assignments';
    document.body.appendChild(link);

    link.dispatchEvent(new MouseEvent('click', { bubbles: true, button: 0 }));

    expect(storedNotice()).toEqual({
      message: 'Your work has been saved.',
      sourceUrl: 'http://localhost/sections/example/lesson/sayg-page',
      targetUrl: 'http://localhost/sections/example/assignments',
    });

    ScoreAsYouGoNavigationNotice.destroyed.call(hook as any);
  });

  test('does not store a notice for external link navigation', () => {
    const source = document.createElement('div');
    source.dataset.message = 'Your work has been saved.';

    const hook = { el: source };
    ScoreAsYouGoNavigationNotice.mounted.call(hook as any);

    const link = document.createElement('a');
    link.href = 'https://example.com';
    document.body.appendChild(link);

    link.dispatchEvent(new MouseEvent('click', { bubbles: true, button: 0 }));

    expect(window.sessionStorage.getItem(storageKey)).toBeNull();

    ScoreAsYouGoNavigationNotice.destroyed.call(hook as any);
  });

  test('does not store a notice for cancelled internal link navigation', () => {
    const source = document.createElement('div');
    source.dataset.message = 'Your work has been saved.';

    const hook = { el: source };
    ScoreAsYouGoNavigationNotice.mounted.call(hook as any);

    const link = document.createElement('a');
    link.href = '/sections/example/assignments';
    link.addEventListener('click', (event) => event.preventDefault());
    document.body.appendChild(link);

    link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 }));

    expect(window.sessionStorage.getItem(storageKey)).toBeNull();

    ScoreAsYouGoNavigationNotice.destroyed.call(hook as any);
  });

  test('does not store a notice for non-self link targets', () => {
    const source = document.createElement('div');
    source.dataset.message = 'Your work has been saved.';

    const hook = { el: source };
    ScoreAsYouGoNavigationNotice.mounted.call(hook as any);

    const link = document.createElement('a');
    link.href = '/sections/example/assignments';
    link.target = '_blank';
    document.body.appendChild(link);

    link.dispatchEvent(new MouseEvent('click', { bubbles: true, button: 0 }));

    expect(window.sessionStorage.getItem(storageKey)).toBeNull();

    ScoreAsYouGoNavigationNotice.destroyed.call(hook as any);
  });

  test('shows and consumes a stored notice on LiveView destinations', () => {
    window.sessionStorage.setItem(
      storageKey,
      JSON.stringify({
        message: 'Your work has been saved.',
        sourceUrl: 'http://localhost/sections/example/lesson/sayg-page',
        targetUrl: 'http://localhost/sections/example/assignments',
      }),
    );
    setLocation('/sections/example/assignments');

    const el = noticeElement();
    const hook = { el };

    ScoreAsYouGoSavedWorkNotice.mounted.call(hook as any);

    expect(el).not.toHaveClass('hidden');
    expect(el.querySelector('[data-sayg-saved-work-message]')).toHaveTextContent(
      'Your work has been saved.',
    );
    expect(window.sessionStorage.getItem(storageKey)).toBeNull();

    el.querySelector<HTMLButtonElement>('[data-sayg-saved-work-dismiss]')?.click();
    expect(el).toHaveClass('hidden');

    ScoreAsYouGoSavedWorkNotice.destroyed.call(hook as any);
  });

  test('clears a stored notice on the source SAYG page without showing it', () => {
    window.sessionStorage.setItem(
      storageKey,
      JSON.stringify({
        message: 'Your work has been saved.',
        sourceUrl: 'http://localhost/sections/example/lesson/sayg-page',
        targetUrl: 'http://localhost/sections/example/assignments',
      }),
    );

    const el = noticeElement();
    const hook = { el };

    ScoreAsYouGoSavedWorkNotice.mounted.call(hook as any);

    expect(el).toHaveClass('hidden');
    expect(window.sessionStorage.getItem(storageKey)).toBeNull();

    ScoreAsYouGoSavedWorkNotice.destroyed.call(hook as any);
  });

  test('shows and consumes a stored notice on static controller-rendered destinations', () => {
    window.sessionStorage.setItem(
      storageKey,
      JSON.stringify({
        message: 'Your work has been saved.',
        sourceUrl: 'http://localhost/sections/example/lesson/sayg-page',
        targetUrl: 'http://localhost/research_consent',
      }),
    );
    setLocation('/research_consent');

    const el = noticeElement(true);

    initializeStaticScoreAsYouGoSavedWorkNotice();

    expect(el).not.toHaveClass('hidden');
    expect(el.querySelector('[data-sayg-saved-work-message]')).toHaveTextContent(
      'Your work has been saved.',
    );
    expect(window.sessionStorage.getItem(storageKey)).toBeNull();
  });
});
