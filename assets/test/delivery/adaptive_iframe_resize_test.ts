import { measureIframeContentHeight } from 'hooks/adaptive_iframe_resize';

const setElementHeight = (element: Element, height: number) => {
  Object.defineProperty(element, 'scrollHeight', { configurable: true, value: height });
  Object.defineProperty(element, 'offsetHeight', { configurable: true, value: height });
  setElementVisualBottom(element, height);
};

const setElementOverflowHeight = (element: Element, layoutHeight: number, scrollHeight: number) => {
  setElementHeight(element, layoutHeight);
  Object.defineProperty(element, 'scrollHeight', { configurable: true, value: scrollHeight });
};

const setElementVisualBottom = (element: Element, bottom: number) => {
  element.getBoundingClientRect = jest.fn(
    () =>
      ({
        bottom,
        height: bottom,
        top: 0,
        left: 0,
        right: 0,
        width: 0,
        x: 0,
        y: 0,
        toJSON: () => ({}),
      } as DOMRect),
  );
};

describe('AdaptiveIframeResize', () => {
  it('uses the minimum height while adaptive stage content is still loading', () => {
    const iframe = document.createElement('iframe');
    document.body.appendChild(iframe);

    const iframeDocument = iframe.contentDocument as Document;
    iframeDocument.body.innerHTML = '<div id="stage-stage"></div>';

    const stage = iframeDocument.querySelector('#stage-stage') as HTMLElement;
    setElementHeight(stage, 640);
    setElementHeight(iframeDocument.body, 2000);
    setElementHeight(iframeDocument.documentElement, 2000);

    expect(measureIframeContentHeight(iframe)).toBe(650);

    iframe.remove();
  });

  it('measures adaptive part bounds when the adaptive container has stretched with the iframe', () => {
    const iframe = document.createElement('iframe');
    document.body.appendChild(iframe);

    const iframeDocument = iframe.contentDocument as Document;
    iframeDocument.body.innerHTML = `
      <div id="stage-stage">
        <div class="stage-content-wrapper">
          <div class="content">
            <janus-text-flow></janus-text-flow>
          </div>
        </div>
      </div>
    `;

    const stage = iframeDocument.querySelector('#stage-stage') as HTMLElement;
    const content = iframeDocument.querySelector('.content') as HTMLElement;
    const textFlow = iframeDocument.querySelector('janus-text-flow') as HTMLElement;
    setElementHeight(stage, 2000);
    setElementHeight(content, 2000);
    setElementHeight(textFlow, 740);
    setElementHeight(iframeDocument.body, 2000);
    setElementHeight(iframeDocument.documentElement, 2000);

    expect(measureIframeContentHeight(iframe)).toBe(740);

    iframe.remove();
  });

  it('ignores adaptive part scroll height that grows with nested iframe content', () => {
    const iframe = document.createElement('iframe');
    document.body.appendChild(iframe);

    const iframeDocument = iframe.contentDocument as Document;
    iframeDocument.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-capi-iframe></janus-capi-iframe>
      </div>
    `;

    const stage = iframeDocument.querySelector('#stage-stage') as HTMLElement;
    const capiIframe = iframeDocument.querySelector('janus-capi-iframe') as HTMLElement;
    capiIframe.setAttribute('model', JSON.stringify({ height: 740 }));
    setElementHeight(stage, 3000);
    setElementHeight(capiIframe, 3000);
    setElementVisualBottom(capiIframe, 3000);
    setElementHeight(iframeDocument.body, 3000);
    setElementHeight(iframeDocument.documentElement, 3000);

    expect(measureIframeContentHeight(iframe)).toBe(740);

    iframe.remove();
  });

  it('includes document content surrounding the adaptive stage', () => {
    const iframe = document.createElement('iframe');
    document.body.appendChild(iframe);

    const iframeDocument = iframe.contentDocument as Document;
    iframeDocument.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-text-flow></janus-text-flow>
      </div>
    `;

    const stage = iframeDocument.querySelector('#stage-stage') as HTMLElement;
    const textFlow = iframeDocument.querySelector('janus-text-flow') as HTMLElement;
    textFlow.setAttribute('model', JSON.stringify({ height: 770 }));
    setElementOverflowHeight(stage, 770, 879);
    setElementHeight(textFlow, 770);
    setElementHeight(iframeDocument.body, 879);
    setElementHeight(iframeDocument.documentElement, 879);

    expect(measureIframeContentHeight(iframe)).toBe(879);

    iframe.remove();
  });

  it('includes stage overflow around regular adaptive parts', () => {
    const iframe = document.createElement('iframe');
    document.body.appendChild(iframe);

    const iframeDocument = iframe.contentDocument as Document;
    iframeDocument.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-text-flow></janus-text-flow>
      </div>
    `;

    const stage = iframeDocument.querySelector('#stage-stage') as HTMLElement;
    const textFlow = iframeDocument.querySelector('janus-text-flow') as HTMLElement;
    textFlow.setAttribute('model', JSON.stringify({ height: 696 }));
    setElementOverflowHeight(stage, 696, 879);
    setElementHeight(textFlow, 696);
    setElementHeight(iframeDocument.body, 696);
    setElementHeight(iframeDocument.documentElement, 696);

    expect(measureIframeContentHeight(iframe)).toBe(879);

    iframe.remove();
  });

  it('ignores stage overflow caused by a CAPI iframe', () => {
    const iframe = document.createElement('iframe');
    document.body.appendChild(iframe);

    const iframeDocument = iframe.contentDocument as Document;
    iframeDocument.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-capi-iframe></janus-capi-iframe>
      </div>
    `;

    const stage = iframeDocument.querySelector('#stage-stage') as HTMLElement;
    const capiIframe = iframeDocument.querySelector('janus-capi-iframe') as HTMLElement;
    capiIframe.setAttribute('model', JSON.stringify({ height: 650 }));
    setElementOverflowHeight(stage, 650, 900);
    setElementHeight(capiIframe, 650);
    setElementHeight(iframeDocument.body, 650);
    setElementHeight(iframeDocument.documentElement, 650);

    expect(measureIframeContentHeight(iframe)).toBe(650);

    iframe.remove();
  });
});
