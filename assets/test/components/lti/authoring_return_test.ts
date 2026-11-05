export {};

describe('standalone authoring return page', () => {
  afterEach(() => {
    document.body.replaceChildren();
    jest.restoreAllMocks();
    jest.useRealTimers();
  });

  it.each(
    ['loading', 'complete'].flatMap((readyState) =>
      [
        { token: 'signed-result', request_id: 'active' },
        { error: 'The tool selection could not be validated.' },
      ].map((result) => ({ readyState, result })),
    ),
  )('returns $result when the document is $readyState', ({ readyState, result }) => {
    jest.useFakeTimers();
    jest.spyOn(document, 'readyState', 'get').mockReturnValue(readyState as DocumentReadyState);
    const postMessage = jest.spyOn(window, 'postMessage').mockImplementation(() => undefined);
    const element = document.createElement('div');
    element.id = 'authoring-result';
    element.dataset.result = JSON.stringify(result);
    document.body.appendChild(element);

    jest.isolateModules(() => require('phoenix/lti_authoring_return'));
    if (readyState === 'loading') {
      expect(postMessage).not.toHaveBeenCalled();
      document.dispatchEvent(new Event('DOMContentLoaded'));
      window.dispatchEvent(new Event('load'));
    }
    jest.runOnlyPendingTimers();

    expect(postMessage).toHaveBeenCalledTimes(1);
    expect(postMessage).toHaveBeenCalledWith(
      { type: 'lti_authoring_deep_link_response', ...result },
      window.location.origin,
    );
  });
});
