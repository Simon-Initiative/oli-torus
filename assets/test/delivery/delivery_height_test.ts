import { getAdaptiveContentHeight } from 'apps/delivery/Delivery';

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

describe('Delivery adaptive iframe height reporting', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('reports the minimum height while adaptive stage content is still loading', () => {
    document.body.innerHTML = '<div id="stage-stage"></div>';

    const stage = document.querySelector('#stage-stage') as HTMLElement;
    setElementHeight(stage, 640);
    setElementHeight(document.body, 2000);
    setElementHeight(document.documentElement, 2000);

    expect(getAdaptiveContentHeight()).toBe(650);
  });

  it('measures adaptive part bounds when the adaptive container has stretched with the iframe', () => {
    document.body.innerHTML = `
      <div id="stage-stage">
        <div class="stage-content-wrapper">
          <div class="content">
            <janus-text-flow></janus-text-flow>
          </div>
        </div>
      </div>
    `;

    const stage = document.querySelector('#stage-stage') as HTMLElement;
    const content = document.querySelector('.content') as HTMLElement;
    const textFlow = document.querySelector('janus-text-flow') as HTMLElement;
    setElementHeight(stage, 2000);
    setElementHeight(content, 2000);
    setElementHeight(textFlow, 740);
    setElementHeight(document.body, 2000);
    setElementHeight(document.documentElement, 2000);

    expect(getAdaptiveContentHeight()).toBe(740);
  });

  it('ignores adaptive part scroll height that grows with nested iframe content', () => {
    document.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-capi-iframe></janus-capi-iframe>
      </div>
    `;

    const stage = document.querySelector('#stage-stage') as HTMLElement;
    const capiIframe = document.querySelector('janus-capi-iframe') as HTMLElement;
    capiIframe.setAttribute('model', JSON.stringify({ height: 740 }));
    setElementHeight(stage, 3000);
    setElementHeight(capiIframe, 3000);
    setElementVisualBottom(capiIframe, 3000);
    setElementHeight(document.body, 3000);
    setElementHeight(document.documentElement, 3000);

    expect(getAdaptiveContentHeight()).toBe(740);
  });

  it('includes document content surrounding the adaptive stage', () => {
    document.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-text-flow></janus-text-flow>
      </div>
    `;

    const stage = document.querySelector('#stage-stage') as HTMLElement;
    const textFlow = document.querySelector('janus-text-flow') as HTMLElement;
    textFlow.setAttribute('model', JSON.stringify({ height: 770 }));
    setElementOverflowHeight(stage, 770, 879);
    setElementHeight(textFlow, 770);
    setElementHeight(document.body, 879);
    setElementHeight(document.documentElement, 879);

    expect(getAdaptiveContentHeight()).toBe(879);
  });

  it('includes stage overflow around regular adaptive parts', () => {
    document.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-text-flow></janus-text-flow>
      </div>
    `;

    const stage = document.querySelector('#stage-stage') as HTMLElement;
    const textFlow = document.querySelector('janus-text-flow') as HTMLElement;
    textFlow.setAttribute('model', JSON.stringify({ height: 696 }));
    setElementOverflowHeight(stage, 696, 879);
    setElementHeight(textFlow, 696);
    setElementHeight(document.body, 696);
    setElementHeight(document.documentElement, 696);

    expect(getAdaptiveContentHeight()).toBe(879);
  });

  it('ignores stage overflow caused by a CAPI iframe', () => {
    document.body.innerHTML = `
      <div data-adaptive-delivery-root data-adaptive-responsive-layout="false"></div>
      <div id="stage-stage">
        <janus-capi-iframe></janus-capi-iframe>
      </div>
    `;

    const stage = document.querySelector('#stage-stage') as HTMLElement;
    const capiIframe = document.querySelector('janus-capi-iframe') as HTMLElement;
    capiIframe.setAttribute('model', JSON.stringify({ height: 650 }));
    setElementOverflowHeight(stage, 650, 900);
    setElementHeight(capiIframe, 650);
    setElementHeight(document.body, 650);
    setElementHeight(document.documentElement, 650);

    expect(getAdaptiveContentHeight()).toBe(650);
  });
});
