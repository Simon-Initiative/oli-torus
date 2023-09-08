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
  });
});
