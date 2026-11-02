import React from 'react';
import { render } from '@testing-library/react';
import { WebpageEmbed } from 'components/webpage/WebpageEmbed';
import { DEFAULT_WEBPAGE_ARIA_LABEL } from 'components/webpage/webpageAriaLabel';
import { Webpage } from 'data/content/model/elements/types';
import { defaultWriterContext } from 'data/content/writers/context';
import { HtmlParser } from 'data/content/writers/html';
import { ContentWriter } from 'data/content/writers/writer';

jest.mock('gleam/torusExpression', () => ({}));

const webpage = (attrs: Partial<Webpage> = {}): Webpage => ({
  type: 'iframe',
  id: 'dom-id',
  src: 'https://phet.colorado.edu/sims/ph-scale',
  alt: 'Alternative text',
  children: [{ text: '' }],
  ...attrs,
});

const renderers: [string, (model: Webpage) => HTMLIFrameElement][] = [
  [
    'WebpageEmbed',
    (model) =>
      render(<WebpageEmbed webpage={{ ...model, targetId: 'target' }} />).container.querySelector(
        'iframe',
      ) as HTMLIFrameElement,
  ],
  [
    'HtmlParser',
    (model) =>
      render(
        <>{new ContentWriter().render(defaultWriterContext(), model, new HtmlParser())}</>,
      ).container.querySelector('iframe') as HTMLIFrameElement,
  ],
];

describe.each(renderers)('%s iframe accessible name', (_name, renderIframe) => {
  it('uses the trimmed authored title as aria-label', () => {
    const iframe = renderIframe(webpage({ title: '  PhET simulation: pH scale  ' }));

    expect(iframe.getAttribute('aria-label')).toBe('PhET simulation: pH scale');
    expect(iframe.hasAttribute('title')).toBe(false);
  });

  it.each([undefined, '', '   '])('falls back to the default label for title %p', (title) => {
    const iframe = renderIframe(webpage({ title }));

    expect(iframe.getAttribute('aria-label')).toBe(DEFAULT_WEBPAGE_ARIA_LABEL);
  });
});
