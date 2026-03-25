import {
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

  it('keeps external embeds non-scrollable unless explicitly enabled', () => {
    expect(
      shouldAllowIframeScrolling(
        {
          allowScrolling: false,
          sourceType: 'url',
        },
        'https://example.com/embed',
      ),
    ).toBe(false);
  });

  it('clamps the iframe part and iframe element to the adaptive slot', () => {
    expect(getIframePartDeliveryStyle({ width: 1200, height: 700 })).toMatchObject({
      width: 1200,
      height: 700,
      maxWidth: '100%',
      maxHeight: '100%',
      overflow: 'hidden',
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
});
