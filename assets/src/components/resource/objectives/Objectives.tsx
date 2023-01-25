import React, { PropsWithChildren } from 'react';

// eslint-disable-next-line @typescript-eslint/ban-types
type Props = {};
export const Objectives = (props: PropsWithChildren<Props>) => {
  return (
    <div className="objectives bg-gray-100 max-w-full py-4 px-6 rounded-md border border-gray-300">
      <h5>Learning Objectives</h5>
      <div className="d-flex flex-row align-items-baseline">
        <div className="flex-grow-1">{props.children}</div>
      </div>
    </div>
  );
};
