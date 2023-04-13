import React from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from 'data/content/model/elements/types';

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
