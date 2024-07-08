import React from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';

export interface VegaLiteSpec {
  spec: VisualizationSpec;
}

export const VegaLiteRenderer = (props: VegaLiteSpec) => {
  return (
    <>
      <VegaLite spec={props.spec} actions={false} />
    </>
  );
};
