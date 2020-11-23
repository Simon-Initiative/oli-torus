
import React from 'react';

// Your basic undo redo toolbar
export const UndoRedo = ({ canUndo, canRedo, onUndo, onRedo }
  : {canUndo: boolean, canRedo: boolean, onUndo: () => void, onRedo: () => void}) => {

  return (
    <div className="btn-group btn-group-sm ml-3" role="group" aria-label="Undo redo creation">
      <button className={'btn btn-sm btn-light'}
        disabled={!canUndo}
        type="button"
        onClick={onUndo}>
        <span><i className="fas fa-undo"></i> Undo</span>
      </button>
      <button className={'btn btn-sm btn-light'}
        disabled={!canRedo}
        type="button"
        onClick={onRedo}>
      <span>Redo <i className="fas fa-redo"></i></span>
      </button>
    </div>
  );
};
