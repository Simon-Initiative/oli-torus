import {
  Heading,
  ImageBlock,
  InputRef,
  Paragraph,
} from '../../../src/data/content/model/elements/types';
import { FormattedText } from '../../../src/data/content/model/text';
import { isEmptyContent } from '../../../src/data/content/utils';

const createPara = (children: (InputRef | FormattedText | ImageBlock)[]): Paragraph => ({
  type: 'p',
  id: 'a',
  children,
});

const createHeading = (children: FormattedText[]): Heading => ({
  type: 'h1',
  id: 'a',
  children,
});

describe('isEmptyContent', () => {
  it('should detect empty content on a whitespace text only node', () => {
    expect(isEmptyContent([{ text: '' }])).toBe(true);
    expect(isEmptyContent([{ text: '  ' }])).toBe(true);
    expect(isEmptyContent([{ text: '\n' }])).toBe(true);
    expect(isEmptyContent([{ text: '\t' }])).toBe(true);
    expect(isEmptyContent([{ text: '\t' }, { text: ' ' }])).toBe(true);
  });

  it('should not detect empty content on strings', () => {
    expect(isEmptyContent([{ text: 'Test' }])).toBe(false);
    expect(isEmptyContent([{ text: '  Test' }])).toBe(false);
    expect(isEmptyContent([{ text: '\nTest' }])).toBe(false);
  });

  it('should detect empty content on empty headings', () => {
    expect(isEmptyContent([createHeading([{ text: '' }])])).toBe(true);
    expect(isEmptyContent([createHeading([{ text: ' ' }])])).toBe(true);
    expect(isEmptyContent([createHeading([{ text: '\n' }])])).toBe(true);
  });

  it('should not detect empty content on non-empty headings', () => {
    expect(isEmptyContent([createHeading([{ text: 'Test' }])])).toBe(false);
    expect(isEmptyContent([createHeading([{ text: ' Test' }])])).toBe(false);
    expect(isEmptyContent([createHeading([{ text: '\nTest' }])])).toBe(false);
  });

  it('should detect empty content on empty paragraphs', () => {
    expect(isEmptyContent([createPara([{ text: '' }])])).toBe(true);
    expect(isEmptyContent([createPara([{ text: ' ' }])])).toBe(true);
    expect(isEmptyContent([createPara([{ text: '\n' }])])).toBe(true);
  });

  it('should not detect empty content on non-empty paragraphs', () => {
    expect(isEmptyContent([createPara([{ text: 'Test' }])])).toBe(false);
    expect(isEmptyContent([createPara([{ text: ' Test' }])])).toBe(false);
    expect(isEmptyContent([createPara([{ text: '\nTest' }])])).toBe(false);
  });

  it('should not detect empty content on block elements', () => {
    expect(isEmptyContent([{ type: 'table', id: 'a', children: [] }])).toBe(false);
  });
});
