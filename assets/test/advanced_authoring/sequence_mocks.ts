import { SequenceBank, SequenceEntry } from 'apps/delivery/store/features/groups/actions/sequence';

export const simpleSequence: SequenceEntry<SequenceBank>[] = [
  {
    resourceId: 1,
    custom: {
      isBank: true,
      sequenceId: '1',
      sequenceName: 'Sequence Item 1',
      bankEndTarget: 'Next',
      bankShowCount: 1,
    },
  },
  {
    resourceId: 2,
    custom: {
      isBank: true,
      sequenceId: '2',
      sequenceName: 'Sequence Item 2',
      layerRef: '1',
      bankEndTarget: 'Next',
      bankShowCount: 1,
    },
  },
];
