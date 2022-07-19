import React from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';

export const CalloutEditor = (props: EditorProps<ContentModel.Callout>) => {
  return (
    <div className="callout-block" {...props.attributes}>
      {props.children}
    </div>
  );
};

export const InlineCalloutEditor = (props: EditorProps<ContentModel.CalloutInline>) => {
  return (
    <span className="callout-inline" {...props.attributes}>
      {props.children}
    </span>
  );
};
