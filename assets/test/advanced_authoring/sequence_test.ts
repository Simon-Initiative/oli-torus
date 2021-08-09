import { getHierarchy } from 'apps/delivery/store/features/groups/actions/sequence';
import { simpleSequence } from './sequence_mocks';

describe('Sequence Util Methods', () => {
  describe('getHierarchy', () => {
    it('should return the sequence in heirarchal form', () => {
      const hierarchy = getHierarchy(simpleSequence);
      expect(hierarchy.length).toBe(1);
      expect(hierarchy[0].children.length).toBe(1);
      expect(hierarchy[0].children[0].custom.sequenceName).toBe(simpleSequence[1].custom.sequenceName);
    });
  });
});
