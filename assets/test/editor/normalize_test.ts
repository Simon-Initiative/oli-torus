import { Model } from 'data/content/model/elements/factories';
import { expectAnyId, runNormalizer } from './normalize-test-utils';

describe('editor / normalizer', () => {
  it('Should wrap root text in paragraphs', () => {
    const original = [{ text: 'Hello There' }];
    const expected = expectAnyId([Model.p([{ text: 'Hello There' }])]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });

  it('Should remove restricted elements', () => {
    const original = [Model.p([Model.inputRef(), { text: 'Hello There' }])];
    const expected = expectAnyId([Model.p([{ text: 'Hello There' }])]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });
});
