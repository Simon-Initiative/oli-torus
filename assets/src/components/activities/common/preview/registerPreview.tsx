import React from 'react';
import ReactDOM from 'react-dom';
import { PreviewElement, PreviewElementProps } from 'components/activities/PreviewElement';
import { PreviewElementProvider } from 'components/activities/PreviewElementProvider';
import { ActivityModelSchema, Manifest } from 'components/activities/types';

export const registerPreviewComponent = (
  manifest: Manifest,
  Component: React.ComponentType,
  displayName: string,
) => {
  class ActivityPreviewElement extends PreviewElement<ActivityModelSchema> {
    render(mountPoint: HTMLDivElement, props: PreviewElementProps<ActivityModelSchema>) {
      ReactDOM.render(
        <PreviewElementProvider {...props}>
          <Component />
        </PreviewElementProvider>,
        mountPoint,
      );
    }
  }

  Object.defineProperty(ActivityPreviewElement, 'name', { value: displayName });

  if (!window.customElements.get(manifest.preview!.element)) {
    window.customElements.define(manifest.preview!.element, ActivityPreviewElement);
  }
};
