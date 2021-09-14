import { MultiInputDelivery } from 'components/activities/multi_input/schema';
import { ID } from 'data/content/model';

export interface WriterContext {
  sectionSlug?: string;
  inputRefContext?: {
    onChange: (id: string, e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => void;
    inputs: Map<ID, { input: MultiInputDelivery; value: string; placeholder?: string }>;
    disabled: boolean;
  };
}

export const defaultWriterContext = (params: Partial<WriterContext> = {}) =>
  Object.assign({}, params);
