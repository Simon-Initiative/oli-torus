export interface WriterContext {
  sectionSlug?: string;
}

export const defaultWriterContext = (params: Partial<WriterContext> = {}) =>
  (Object.assign({}, params));
