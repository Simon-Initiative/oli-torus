import React, { ReactNode } from 'react';
import { Mafs, Coordinates, Plot, Theme } from "mafs"

export const Graph: React.FC<{
  children?: ReactNode;
  src: string;
}> = React.memo(({ src }) => {


  let fn = (x: number) => x;
  let evalFn = null;
  try {
    evalFn = eval(src);
    fn = evalFn;
  } catch (e) {
    console.error(e);
  }

  if (evalFn === null || typeof evalFn !== 'function') {
    fn = (x: number) => x;
  } else {
    try {
      evalFn(0);
    } catch (e) {
      console.error(e);
      fn = (x: number) => x;
    }
  }

  return (
    <Mafs>
      <Coordinates.Cartesian />
      <Plot.OfX y={fn} color={Theme.blue} />
    </Mafs>
  )
});

Graph.displayName = 'Graph';
