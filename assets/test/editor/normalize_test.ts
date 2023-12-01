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

  it('Should not lose invalid children of paragraphs', () => {
    const original = [
      Model.p([{ text: 'Before ' }, Model.formula('mathml', '1+1') as any]),
      { text: ' after.' },
    ];

    const expected = expectAnyId([
      Model.p([{ text: 'Before ' }]),
      Model.formula('mathml', '1+1'),
      Model.p([{ text: ' after.' }]),
    ]);
    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(expected);
  });
});
