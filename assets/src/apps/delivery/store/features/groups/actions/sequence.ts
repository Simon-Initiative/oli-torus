export interface SequenceEntryChild {
  sequenceId: string;
  sequenceName: string;
  layerRef?: string;
  isBank?: boolean;
  isLayer?: boolean;
}

export interface SequenceLayer extends SequenceEntryChild {
  isLayer: true;
}

export interface SequenceBank extends SequenceEntryChild {
  isBank: true;
  bankShowCount: number;
  bankEndTarget: string;
}

export type SequenceEntryType = SequenceEntryChild | SequenceLayer | SequenceBank;

export interface SequenceEntry<T> {
  activity_id: number;
  custom: T;
}