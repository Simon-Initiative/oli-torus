import { Descendant } from 'slate';
import { Model } from 'data/content/model/elements/factories';
import { expectAnyId, runNormalizer } from './normalize-test-utils';

describe('editor / root node normalizer', () => {
  it('Should force root node to be a conjugation table', () => {
    const original = [Model.p('Hello There')];
    const expected = expectAnyId([Model.conjugationTable()]);
    const { editor } = runNormalizer(original as any, {
      normalizerOptions: {
        insertParagraphStartEnd: false,
        forceRootNode: Model.conjugationTable(),
      },
    });
    expect(editor.children).toEqual(expected);
  });

  it('Should insert a root node if there are none', () => {
    const original: Descendant[] = [];
    const expected = expectAnyId([Model.conjugationTable()]);
    const { editor } = runNormalizer(original as any, {
      normalizerOptions: {
        insertParagraphStartEnd: false,
        forceRootNode: Model.conjugationTable(),
      },
    });
    expect(editor.children).toEqual(expected);
  });
});
