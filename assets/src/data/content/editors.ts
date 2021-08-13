import React from 'react';

export type EditorDesc = {
  slug: string;
  deliveryElement: string | React.FunctionComponent;
  authoringElement: string | React.FunctionComponent;
  icon: string;
  description: string;
  friendlyName: string;
  globallyAvailable: boolean;
  enabledForProject: boolean;
};

export interface ActivityEditorMap {
  // Index signature
  [prop: string]: EditorDesc;
}
