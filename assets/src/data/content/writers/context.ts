import { MultiInputDelivery } from 'components/activities/multi_input/schema';
import { VlabInputDelivery } from 'components/activities/vlab/schema';
import { ID } from 'data/content/model/other';

export interface WriterContext {
  sectionSlug?: string;
  projectSlug?: string;
  bibParams?: any;
  inputRefContext?: {
    onChange: (id: string, value: string) => void;
    toggleHints: (id: string) => void;
    inputs: Map<
      ID,
      {
        input: MultiInputDelivery | VlabInputDelivery;
        value: string;
        placeholder?: string;
        hasHints: boolean;
      }
    >;
    disabled: boolean;
  };
}

export const defaultWriterContext = (params: Partial<WriterContext> = {}) =>
  Object.assign({}, params);
