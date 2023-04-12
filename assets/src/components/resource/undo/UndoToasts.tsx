import { Undoables } from '../../../apps/page-editor/types';
import styles from './UndoToasts.modules.scss';
import * as React from 'react';
import { CSSTransition, TransitionGroup } from 'react-transition-group';

export type UndoToastsProps = {
  undoables: Undoables;
  onInvokeUndo: (guid: string) => void;
};

const toProperCase = (text: string) => {
  return text.replace(/\w\S*/g, (s: string) => {
    return s.charAt(0).toUpperCase() + s.substr(1).toLowerCase();
  });
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
        classNames={{
          enter: styles.undoToastEnter,
          enterActive: styles.undoToastEnterActive,
          exit: styles.undoToastLeave,
          exitActive: styles.undoToastLeaveActive,
        }}
      >
        <div key={key} className={styles.undoToast}>
          <div className="toast-body d-flex justify-content-between">
            <span className="undo-toast-desc">{toProperCase(action.undoable.description)}</span>
            <button onClick={() => props.onInvokeUndo(key)} className="btn btn-primary btn-xs">
              Undo
            </button>
          </div>
        </div>
      </CSSTransition>
    );
  });

  return (
    <div className={styles.undoToasts}>
      <TransitionGroup>{toasts}</TransitionGroup>
    </div>
  );
};
