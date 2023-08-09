import { Descendant } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { ModelTypes } from 'data/content/model/schema';
import { expectAnyEmptyParagraph, expectAnyId, runNormalizer } from './normalize-test-utils';

describe('editor / spaces normalizer', () => {
  const elementsToLeaveAlone: ModelTypes[] = [
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'conjugation',
    'formula',
    'math',
  ];

  const elementsToAddSpaces: ModelTypes[] = [
    'img',
    'youtube',
    'audio',
    'blockquote',
    'code',
    'table',
    'iframe',
    'definition',
    'figure',
    'callout',
    'dialog',
  ];

  for (const elementType of elementsToAddSpaces) {
    it(`Should add paragraph between ${elementType} block elements`, () => {
      const original = [
        Model.p(),
        { type: elementType, id: '1', children: [{ text: '' }] },
        { type: elementType, id: '2', children: [{ text: '' }] },
        Model.p(),
      ] as Descendant[];

      const expected = expectAnyId([
        expectAnyEmptyParagraph,
        { type: elementType, id: '1', children: [{ text: '' }] },
        expectAnyEmptyParagraph,
        { type: elementType, id: '2', children: [{ text: '' }] },
        expectAnyEmptyParagraph,
      ] as Descendant[]);

      const { editor } = runNormalizer(original);

      expect(editor.children).toEqual(expected);
    });
  }

  for (const elementType of elementsToLeaveAlone) {
    it(`Should not add paragraph between ${elementType} block elements`, () => {
      const original = [
        Model.p(),
        { type: elementType, id: '1', children: [{ text: '' }] },
        { type: elementType, id: '2', children: [{ text: '' }] },
        Model.p(),
      ] as Descendant[];

      const expected = expectAnyId([
        expectAnyEmptyParagraph,
        { type: elementType, id: '1', children: [{ text: '' }] },
        { type: elementType, id: '2', children: [{ text: '' }] },
        expectAnyEmptyParagraph,
      ] as Descendant[]);

      const { editor } = runNormalizer(original);

      //console.log(JSON.stringify(editor.children, null, 2));
      expect(editor.children).toEqual(expected);
    });
  }
});
