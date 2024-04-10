import { Model } from 'data/content/model/elements/factories';
import { expectAnyId, runNormalizer } from './normalize-test-utils';

describe('editor / root normalizer', () => {
  describe('editor / root normalizer', () => {
    it('Should insert paragraph at beginning of doc.', () => {
      const original = [Model.image(), Model.p()];

      const expected = expectAnyId([Model.p(), Model.image(), Model.p()]);

      const { editor } = runNormalizer(original);
      expect(editor.children).toEqual(expected);
    });

    it('Should insert paragraph at end of doc.', () => {
      const original = [Model.p(), Model.image()];

      const expected = expectAnyId([Model.p(), Model.image(), Model.p()]);

      const { editor } = runNormalizer(original);
      expect(editor.children).toEqual(expected);
    });

    it('Should insert paragraph at both ends of doc.', () => {
      const original = [Model.image()];

      const expected = expectAnyId([Model.p(), Model.image(), Model.p()]);

      const { editor } = runNormalizer(original);
      expect(editor.children).toEqual(expected);
    });

    it('Should fix duplicate block ids.', () => {
      const original = [
        { ...Model.p(), id: 'identical' },
        { ...Model.p(), id: 'identical' },
        Model.p(),
      ];

      const originalParagraphOne = original[0] as any;
      const originalParagraphTwo = original[1] as any;
      const originalParagraphThree = original[2] as any;

      expect(originalParagraphOne.id).toEqual(originalParagraphTwo.id);

      const { editor } = runNormalizer(original);

      const normalizedParagraphOne = editor.children[0] as any;
      const normalizedParagraphTwo = editor.children[1] as any;
      const normalizedParagraphThree = editor.children[2] as any;

      expect(normalizedParagraphOne.id).not.toEqual(normalizedParagraphTwo.id);
      expect(originalParagraphThree.id).toEqual(normalizedParagraphThree.id);
    });
  });
});
