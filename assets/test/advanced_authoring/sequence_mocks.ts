import {
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';

export const simpleSequence: SequenceEntry<SequenceEntryChild>[] = [
  {
    resourceId: 1,
    custom: {
      sequenceId: '1',
      sequenceName: 'Sequence Item 1',
    },
  },
  {
    resourceId: 2,
    custom: {
      sequenceId: '2',
      sequenceName: 'Sequence Item 2',
      layerRef: '1',
    },
  },
];
