import React from 'react';
import { useSelected } from 'slate-react';

interface Props {
  attributes: unknown;
  children: unknown;
}
export const Placeholder = (props: Props) => {
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
        <header>
          <h3 className="d-flex align-items-center">
            <span className="material-icons mr-2">image</span>Image
          </h3>
        </header>
        Upload an image from your media library or add one with a URL.
        <div>
          <button className="btn btn-primary mr-2">Upload</button>
          <button className="btn btn-link">Insert from URL</button>
          {props.children}
        </div>
      </div>
    </div>
  );
};
