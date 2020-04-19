
import React from 'react';

// Your basic undo redo toolbar
export const UndoRedo = ({ canUndo, canRedo, onUndo, onRedo }
  : {canUndo: boolean, canRedo: boolean, onUndo: () => void, onRedo: () => void}) => {

  return (
    <div className="btn-group btn-group-sm" role="group" aria-label="Undo redo creation">
      <button className={`btn ${canUndo ? '' : 'disabled'}`} type="button" onClick={onUndo}>
        <span><i className="fas fa-undo"></i></span>
      </button>
      <button className={`btn ${canRedo ? '' : 'disabled'}`} type="button" onClick={onRedo}>
      <span><i className="fas fa-redo"></i></span>
      </button>
    </div>
  );
};
