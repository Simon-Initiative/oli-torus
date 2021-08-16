import {
  findInSequence,
  findInSequenceByResourceId,
  getHierarchy,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { simpleSequence } from './sequence_mocks';

describe('Sequence Util Methods', () => {
  describe('getHierarchy', () => {
    it('should return the sequence in heirarchal form', () => {
      const hierarchy = getHierarchy(simpleSequence);
      expect(hierarchy.length).toBe(1);
      expect(hierarchy[0].children.length).toBe(1);
      expect(hierarchy[0].children[0].custom.sequenceName).toBe(
        simpleSequence[1].custom.sequenceName,
      );
    });
  });

  describe('findInSequence', () => {
    it('should return a sequence entry by looking for the sequence id', () => {
      const entry = findInSequence(simpleSequence, '2');
      expect(entry).not.toBe(null);
      expect(entry?.custom.sequenceName).toBe('Sequence Item 2');
    });

    it("should return null when it doesn't find the sequence id", () => {
      const entry = findInSequence(simpleSequence, '3');
      expect(entry).toBe(null);
    });

    it('should find an entry in a sequence by resourceId', () => {
      const entry = findInSequenceByResourceId(simpleSequence, 2);
      expect(entry).not.toBe(null);
      expect(entry?.custom.sequenceName).toBe('Sequence Item 2');
    });
  });
});
