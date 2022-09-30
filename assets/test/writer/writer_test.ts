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

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'img' &&
          element?.getAttribute('src') ===
            'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg/480px-Declaration_of_Independence_%281819%29%2C_by_John_Trumbull.jpg'
        );
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'p' &&
          content.startsWith(
            'The American colonials proclaimed "no taxation without representation',
          )
        );
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'a' &&
          element.getAttribute('href') === '#' &&
          content === 'Page Two'
        );
      }),
    ).toBeTruthy();

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

    expect(
      screen.getByText((content, element) => {
        return element?.tagName.toLowerCase() === 'h3' && content === '1651–1748: Early seeds';
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'ol' &&
          Array.from(element.childNodes).every((node) => node.nodeName.toLowerCase() === 'li')
        );
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'ul' &&
          Array.from(element.childNodes).every((node) => node.nodeName.toLowerCase() === 'li')
        );
      }),
    ).toBeTruthy();

    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'iframe' &&
          element.getAttribute('src') === 'https://www.youtube.com/embed/fhdCslFcKFU' &&
          content === ''
        );
      }),
    ).toBeTruthy();
  });

  it('renders internal link with context', () => {
    render(parse(exampleContent, defaultWriterContext({ sectionSlug: 'some_section' })));
    expect(
      screen.getByText((content, element) => {
        return (
          element?.tagName.toLowerCase() === 'a' &&
          element.getAttribute('href') === '/sections/some_section/page/page_two' &&
          content === 'Page Two'
        );
      }),
    ).toBeTruthy();
  });

  it('renders malformed page gracefully', () => {
    render(parse(exampleMalformedContent));

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
  });

  it('renders unsupported content gracefully', () => {
    render(parse(exampleUnsupportedContent));

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
  });
});
