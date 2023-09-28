import { Model } from 'data/content/model/elements/factories';
import { expectAnyEmptyParagraph, runNormalizer } from './normalize-test-utils';

describe('Empty element normalization', () => {
  it('should not touch well formed links', () => {
    const original = [Model.p('Hello World')];
    const link = Model.link('https://example.com');
    link.children = [{ text: 'Hello World' }];
    original[0].children = [{ text: '' }, link, { text: '' }];

    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual(original);
  });

  it('should remove an empty link', () => {
    const original = [Model.p('Hello World')];
    const link = Model.link('https://example.com');
    original[0].children = [link];

    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual([expectAnyEmptyParagraph]);
  });

  it('should remove an empty foreign tag', () => {
    const original = [Model.p('Hello World')];
    const foreign = Model.foreign();
    original[0].children = [foreign];

    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual([expectAnyEmptyParagraph]);
  });

  it('should remove an empty callout', () => {
    const original = [Model.p(), Model.callout('')];

    const { editor } = runNormalizer(original);
    expect(editor.children).toEqual([expectAnyEmptyParagraph]);
  });
});
