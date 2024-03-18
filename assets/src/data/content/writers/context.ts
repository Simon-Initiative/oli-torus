import { MultiInputDelivery } from 'components/activities/multi_input/schema';
import { VlabInputDelivery } from 'components/activities/vlab/schema';
import { ID } from 'data/content/model/other';

export interface WriterContext {
  resourceId?: number;
  graded?: boolean;
  sectionSlug?: string;
  projectSlug?: string;
  bibParams?: any;
  learningLanguage?: string;
  resourceAttemptGuid?: string;
  inputRefContext?: {
    onBlur: (id: string) => void;
    onPressEnter: (id: string) => void;
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
  renderPointMarkers?: boolean;
  isAnnotationLevel?: boolean;
}

export const defaultWriterContext = (params: Partial<WriterContext> = {}): WriterContext =>
  Object.assign({}, params);
