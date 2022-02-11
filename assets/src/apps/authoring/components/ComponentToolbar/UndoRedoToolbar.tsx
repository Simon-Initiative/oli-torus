import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';

import { selectPaths } from '../../store/app/slice';
import { undo } from 'apps/authoring/store/history/actions/undo';
import { redo } from 'apps/authoring/store/history/actions/redo';
import { selectHasRedo, selectHasUndo } from 'apps/authoring/store/history/slice';

const UndoRedoToolbar: React.FC = () => {
  const paths = useSelector(selectPaths);
  const dispatch = useDispatch();

  const hasRedo = useSelector(selectHasRedo);
  const hasUndo = useSelector(selectHasUndo);

  const handleUndo = () => {
    dispatch(undo(null));
  };

  const handleRedo = () => {
    dispatch(redo(null));
  };

  return (
    <>
      <OverlayTrigger
        placement="bottom"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Undo
          </Tooltip>
        }
      >
        <button
          className="px-2 btn btn-link"
          onClick={() => handleUndo()}
          disabled={!hasUndo}
          style={{ opacity: !hasUndo ? '0.25' : '1', pointerEvents: !hasUndo ? 'none' : 'auto' }}
        >
          <img src={`${paths?.images}/icons/icon-undo.svg`} className="icon-undo icon-history" />
        </button>
      </OverlayTrigger>
      <OverlayTrigger
        placement="bottom"
        delay={{ show: 150, hide: 150 }}
        overlay={
          <Tooltip id="button-tooltip" style={{ fontSize: '12px' }}>
            Undo
          </Tooltip>
        }
      >
        <button
          className="px-2 btn btn-link"
          onClick={() => handleRedo()}
          disabled={!hasRedo}
          style={{ opacity: !hasRedo ? '0.25' : '1', pointerEvents: !hasRedo ? 'none' : 'auto' }}
        >
          <img src={`${paths?.images}/icons/icon-redo.svg`} className="icon-redo icon-history" />
        </button>
      </OverlayTrigger>
    </>
  );
};

export default UndoRedoToolbar;
