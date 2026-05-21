import React, { useContext } from 'react';
import { Maybe } from 'tsmonad';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { WriterContext, defaultWriterContext } from 'data/content/writers/context';
import { PreviewElementProps } from './PreviewElement';
import { ActivityModelSchema, PreviewContext } from './types';

export interface PreviewElementState<
  T extends ActivityModelSchema,
  C extends PreviewContext = PreviewContext,
> extends PreviewElementProps<T, C> {
  writerContext: WriterContext;
}

const PreviewElementContext = React.createContext<PreviewElementState<any> | undefined>(undefined);

export function usePreviewElementContext<
  T extends ActivityModelSchema,
  C extends PreviewContext = PreviewContext,
>() {
  return Maybe.maybe(
    useContext(PreviewElementContext) as PreviewElementState<T, C> | undefined,
  ).valueOrThrow(
    new Error('usePreviewElementContext must be used within a PreviewElementProvider'),
  );
}

export const PreviewElementProvider: React.FC<PreviewElementProps<any>> = (props) => {
  const writerContext = defaultWriterContext({
    resourceId: props.previewContext.pageResourceId,
    sectionSlug: props.previewContext.sectionSlug,
    bibParams: props.previewContext.bibParams,
  });

  return (
    <PreviewElementContext.Provider value={{ ...props, writerContext }}>
      <ErrorBoundary>{props.children}</ErrorBoundary>
    </PreviewElementContext.Provider>
  );
};
