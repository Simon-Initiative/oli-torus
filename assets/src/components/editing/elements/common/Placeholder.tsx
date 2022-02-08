import React, { PropsWithChildren } from 'react';
import { useSelected } from 'slate-react';

interface Props {
  attributes: any;
  heading: JSX.Element;
}
export const Placeholder = (props: PropsWithChildren<Props>) => {
  const selected = useSelected();
  return (
    <div
      {...props.attributes}
      style={{ border: selected ? '3px solid blue' : '3px solid transparent', borderRadius: 3 }}
    >
      <div
        contentEditable={false}
        style={{ border: selected ? '1px solid transparent' : '1px solid black', padding: 16 }}
      >
        <header>{props.heading}</header>
        {props.children}
      </div>
    </div>
  );
};
