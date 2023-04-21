import { SequenceBank, SequenceEntry } from 'apps/delivery/store/features/groups/actions/sequence';

export const transformedSchema = {
  bankShowCount: 3,
  bankEndTarget: 'next',
};

export const bank: SequenceEntry<SequenceBank> = {
  resourceId: 1,
  custom: {
    isBank: true,
    sequenceId: '1',
    sequenceName: 'Sequence Item 1',
    bankEndTarget: 'Next',
    bankShowCount: 3,
  },
};
