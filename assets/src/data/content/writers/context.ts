import { MultiInput } from 'components/activities/multi_input/schema';
import { ID } from 'data/content/model';

export interface WriterContext {
  sectionSlug?: string;
  inputRefContext?: {
    onChange: (id: string, e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => void;
    inputs: Map<ID, { input: MultiInput; value: string }>;
    disabled: boolean;
  };
}

export const defaultWriterContext = (params: Partial<WriterContext> = {}) =>
  Object.assign({}, params);
