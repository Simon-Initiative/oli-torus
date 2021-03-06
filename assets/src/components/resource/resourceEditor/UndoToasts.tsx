import * as React from 'react';
import { Undoables } from './types';
import { TransitionGroup, CSSTransition } from 'react-transition-group';

export type UndoToastsProps = {
  undoables: Undoables;
  onInvokeUndo: (guid: string) => void;
};

export const UndoToasts = (props: UndoToastsProps) => {
  const toasts = props.undoables.toArray().map((u) => {
    const [key, action] = u;
    return (
      <CSSTransition
        key={key}
        in={true}
        timeout={{
          appear: 500,
          enter: 500,
          exit: 50,
        }}
        classNames="undotoast"
      >
        <div key={key} className="undotoast">
          <div className="toast-body d-flex justify-content-between">
            <span className="undo-toast-desc">{action.undoable.description}</span>
            <button onClick={() => props.onInvokeUndo(key)} className="btn undo-toast-btn btn-sm">
              Undo
            </button>
          </div>
        </div>
      </CSSTransition>
    );
  });

  return (
    <div className="undo-toasts">
      <TransitionGroup>{toasts}</TransitionGroup>
    </div>
  );
};
