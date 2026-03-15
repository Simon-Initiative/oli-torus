import {
  resolveAdaptiveIframeSource,
  sanitizeAdaptiveIframeFallbackHref,
} from 'components/parts/janus-capi-iframe/sourceResolver';

describe('resolveAdaptiveIframeSource', () => {
  it('rewrites internal course links for authoring preview routes', () => {
    const resolved = resolveAdaptiveIframeSource(
      '/course/link/page_two',
      '/authoring/project/demo-course/preview/page-one',
    );

    expect(resolved).toBe('/authoring/project/demo-course/preview/page_two');
  });

  it('rewrites internal course links for authoring resource routes', () => {
    const resolved = resolveAdaptiveIframeSource(
      '/course/link/page_two',
      '/authoring/project/demo-course/resource/page-one',
    );

    expect(resolved).toBe('/authoring/project/demo-course/preview/page_two');
  });

  it('rewrites internal course links for workspace authoring routes', () => {
    const resolved = resolveAdaptiveIframeSource(
      '/course/link/page_two',
      '/workspaces/course_author/demo-course/curriculum/page-one/edit',
    );

    expect(resolved).toBe('/authoring/project/demo-course/preview/page_two');
  });

  it('rewrites internal course links for instructor preview routes', () => {
    const resolved = resolveAdaptiveIframeSource(
      '/course/link/page_two',
      '/sections/demo-section/preview/page/page-one',
    );

    expect(resolved).toBe('/sections/demo-section/preview/page/page_two');
  });

  it('rewrites internal course links for delivery lesson routes', () => {
    const resolved = resolveAdaptiveIframeSource(
      '/course/link/page_two',
      '/sections/demo-section/lesson/page-one',
    );

    expect(resolved).toBe('/sections/demo-section/lesson/page_two');
  });

  it('keeps external urls unchanged', () => {
    const resolved = resolveAdaptiveIframeSource(
      'https://example.org/embed',
      '/authoring/project/demo-course/preview/page-one',
    );

    expect(resolved).toBe('https://example.org/embed');
  });
});

describe('sanitizeAdaptiveIframeFallbackHref', () => {
  it('allows same-origin relative hrefs', () => {
    expect(sanitizeAdaptiveIframeFallbackHref('/sections/demo/lesson/page?x=1#y')).toBe(
      '/sections/demo/lesson/page?x=1#y',
    );
  });

  it('blocks javascript scheme hrefs', () => {
    expect(sanitizeAdaptiveIframeFallbackHref('javascript:alert(1)')).toBe('#');
  });

  it('blocks absolute external hrefs', () => {
    expect(sanitizeAdaptiveIframeFallbackHref('https://evil.test/path')).toBe('#');
  });

  it('blocks protocol-relative hrefs', () => {
    expect(sanitizeAdaptiveIframeFallbackHref('//evil.test/path')).toBe('#');
  });
});
