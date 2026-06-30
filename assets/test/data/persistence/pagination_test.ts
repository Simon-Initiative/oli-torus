import * as Extrinsic from '../../../src/data/persistence/extrinsic';
import { updatePaginationState } from '../../../src/data/persistence/pagination';

jest.mock('../../../src/data/persistence/extrinsic', () => ({
  readAttempt: jest.fn(),
  upsertAttempt: jest.fn(),
}));

describe('updatePaginationState', () => {
  it('does not persist pagination state without a resource attempt guid', async () => {
    await expect(
      updatePaginationState('section_slug' as any, '', 'group-id', [1]),
    ).resolves.toEqual({});

    expect(Extrinsic.readAttempt).not.toHaveBeenCalled();
    expect(Extrinsic.upsertAttempt).not.toHaveBeenCalled();
  });
});
