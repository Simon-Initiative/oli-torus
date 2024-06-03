import React from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';

export interface VegaLiteSpec {
  spec: VisualizationSpec;
}

export const VegaLiteRenderer = (props: VegaLiteSpec) => {
  console.log(' sdhiere');
  console.log(props.spec);
  return (
    <>
      <VegaLite spec={props.spec} />
    </>
  );
};
