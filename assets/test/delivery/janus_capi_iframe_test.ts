import {
  getExternalActivityContainerStyles,
  getExternalIframeStyles,
  getIframePartDeliveryStyle,
  shouldAllowIframeScrolling,
} from 'components/parts/janus-capi-iframe/iframeBehavior';

describe('janus_capi_iframe delivery behavior', () => {
  it('enables scrolling for internal adaptive page embeds even when allowScrolling is false', () => {
    expect(
      shouldAllowIframeScrolling(
        {
          allowScrolling: false,
          sourceType: 'page',
        },
        '/course/link/lesson-one',
      ),
    ).toBe(true);
  });

  it('enables scrolling for external embeds in delivery', () => {
    expect(
      shouldAllowIframeScrolling(
        {
          allowScrolling: false,
          sourceType: 'url',
        },
        'https://example.com/embed',
      ),
    ).toBe(true);
  });

  it('clamps the iframe part to the adaptive slot in normal delivery', () => {
    expect(getIframePartDeliveryStyle({ width: 1200, height: 700 })).toMatchObject({
      width: 1200,
      height: 700,
      boxSizing: 'border-box',
      maxWidth: '100%',
      maxHeight: '100%',
      overflow: 'hidden',
    });
  });

  it('clamps the iframe part to the adaptive slot in ordinary review mode', () => {
    expect(getIframePartDeliveryStyle({ width: 1200, height: 700 }, false)).toMatchObject({
      width: 1200,
      height: 700,
      boxSizing: 'border-box',
      maxWidth: '100%',
      maxHeight: '100%',
      overflow: 'hidden',
    });

    expect(getExternalActivityContainerStyles(1200, 700, false)).toMatchObject({
      width: '100%',
      height: '100%',
      maxWidth: '100%',
      maxHeight: '100%',
      overflow: 'hidden',
    });
  });

  it('preserves the CAPI-reported iframe size when explicitly requested', () => {
    expect(getIframePartDeliveryStyle({ width: 1200, height: 700 }, true)).toMatchObject({
      width: 1200,
      height: 700,
      boxSizing: 'border-box',
      overflow: 'visible',
    });

    expect(getExternalActivityContainerStyles(1200, 700, true)).toMatchObject({
      width: 1200,
      height: 700,
      overflow: 'auto',
    });

    expect(getExternalIframeStyles({ width: '100%', height: '100%' }, true)).toMatchObject({
      width: '100%',
      height: '100%',
      display: 'block',
      maxWidth: '100%',
      maxHeight: '100%',
      overflow: 'auto',
    });
  });

  it('fills and clips the iframe container in normal delivery', () => {
    expect(getExternalActivityContainerStyles(1200, 700)).toMatchObject({
      width: '100%',
      height: '100%',
      maxWidth: '100%',
      maxHeight: '100%',
      overflow: 'hidden',
    });
  });
});
