/* eslint-disable @typescript-eslint/no-var-requires */
import { ContentWriter } from 'data/content/writers/writer';
import { defaultWriterContext } from 'data/content/writers/context';
import { HtmlParser } from 'data/content/writers/html';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

const exampleUnsupportedContent = require('./example_unsupported_content.json');
const exampleMalformedContent = require('./example_malformed_content.json');
const exampleContent = require('./example_content.json');

const parse = (content: any, context = defaultWriterContext()) =>
  new ContentWriter().render(context, content, new HtmlParser());

describe('parser', () => {
  it('renders well-formed content properly', () => {
    render(parse(exampleContent));

    expect(
      screen.getByText((content, element) => {
        return element?.tagName.toLowerCase() === 'h3' && content === 'Introduction';
      }),
    ).toBeTruthy();
    const htmlString = parse(exampleContent);
    // expect(htmlString).toContain('<h3>Introduction</h3>');

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'img' &&
          element?.getAttribute('src') ===
            'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg'
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toMatch(
    //   new RegExp(
    //     '<img.* src="https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg"/>',
    //   ),
    // );

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'p' &&
          content.startsWith(
            'The American colonials proclaimed &quot;no taxation without representation',
          )
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toContain(
    //   '<p>The American colonials proclaimed &quot;no taxation without representation',
    // );

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'a' &&
          element.getAttribute('href') === '#' &&
          content === 'Page Two'
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toContain('<a class="internal-link" href="#">Page Two</a>');

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'a' &&
          element.className === 'external-link' &&
          element.getAttribute('href') === 'https://en.wikipedia.org/wiki/Stamp_Act_Congress' &&
          content === 'Stamp Act Congress'
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toContain(
    //   '<a class="external-link" href="https://en.wikipedia.org/wiki/Stamp_Act_Congress" target="_blank">Stamp Act Congress</a>',
    // );

    expect(
      screen.getByText((content, element) => {
        return element?.tagName.toLowerCase() === 'h3' && content === '1651–1748: Early seeds';
      }),
    ).toBeTruthy();
    // expect(htmlString).toContain('<h3>1651–1748: Early seeds</h3>');
    // expect(htmlString).toContain(
    //   '<ol><li>one</li>\n<li><em>two</em></li>\n<li><em><strong>three</strong></em></li>\n</ol>',
    // );

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'ol' &&
          [...element.childNodes.values()].every((node) => node.nodeName.toLowerCase() === 'li')
        );
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'ul' &&
          [...element.childNodes.values()].every((node) => node.nodeName.toLowerCase() === 'li')
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toContain('<ul><li>alpha</li>\n<li>beta</li>\n<li>gamma</li>\n</ul>');

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'iframe' &&
          element.getAttribute('src') === 'https://www.youtube.com/embed/fhdCslFcKFU' &&
          content === ''
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toMatch(
    //   new RegExp('<iframe.* src="https://www.youtube.com/embed/fhdCslFcKFU"></iframe>'),
    // );

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'pre' &&
          element?.firstChild?.nodeName.toLowerCase() === 'code' &&
          !!element?.firstChild.textContent?.includes('import fresh-pots')
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toMatch(new RegExp('<pre><code.*>import fresh-pots\n</code></pre>'));
  });

  it('renders internal link with context', () => {
    render(parse(exampleContent, defaultWriterContext({ sectionSlug: 'some_section' })));
    // const htmlString = parse(exampleContent, defaultWriterContext({ sectionSlug: 'some_section' }));
    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'a' &&
          element.getAttribute('href') === '/sections/some_section/page/page_two' &&
          content === 'Page Two'
        );
      }),
    ).toBeTruthy();
    // expect(htmlString).toContain(
    //   '<a class="internal-link" href="/sections/some_section/page/page_two">Page Two</a>',
    // );
  });

  it('renders malformed page gracefully', () => {
    render(parse(exampleMalformedContent));
    const htmlString = parse(exampleMalformedContent);

    expect(
      screen.getByText((content, element) => {
        return element?.tagName.toLowerCase() === 'h3' && content === 'Introduction';
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'div' &&
          element.className === 'content invalid' &&
          content === 'Content element is invalid'
        );
      }),
    ).toBeTruthy();

    // expect(htmlString).toContain('<h3>Introduction</h3>');
    // expect(htmlString).toContain('<div class="content invalid">Content element is invalid');
  });
  it('renders unsupported content gracefully', () => {
    render(parse(exampleUnsupportedContent));
    const htmlString = parse(exampleUnsupportedContent);

    expect(
      screen.getByText((content, element) => {
        return element?.tagName.toLowerCase() === 'h3' && content === 'Introduction';
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'div' &&
          element.className === 'content invalid' &&
          content === 'Content element is invalid'
        );
      }),
    ).toBeTruthy();

    // expect(htmlString).toContain('<h3>Introduction</h3>');
    // expect(htmlString).toContain('<div class="content invalid">Content element is invalid');
  });
});
