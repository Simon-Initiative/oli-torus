import React, { PropsWithChildren } from 'react';

type Props = PropsWithChildren<{
  children: JSX.Element;
  onDone: (event: React.MouseEvent<HTMLSpanElement, MouseEvent>) => void;
  onCancel: (event: React.MouseEvent<HTMLSpanElement, MouseEvent>) => void;
}>;
export const FullScreenModal = React.memo(function FullScreenModal(props: Props) {
  return (
    <div className="overlay full-screen">
      <button type="button" className="close">
        <span onClick={props.onCancel} aria-hidden="true" className="material-icons">
          close
        </span>
      </button>
      <div className="overlay-dialog">
        <div className="overlay-content">{props.children}</div>
        <div className="overlay-actions">
          <button type="button" onClick={props.onDone} className="mr-2 btn btn-outline-primary">
            Save
          </button>
          <button type="button" onClick={props.onCancel} className="btn btn-outline-dark">
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
});
