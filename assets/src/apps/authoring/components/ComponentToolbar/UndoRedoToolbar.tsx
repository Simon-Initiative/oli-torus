import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';

import { selectPaths } from '../../store/app/slice';
import { undo } from 'apps/authoring/store/history/actions/undo';
import { redo } from 'apps/authoring/store/history/actions/redo';

const UndoRedoToolbar: React.FC = () => {
  const paths = useSelector(selectPaths);
  const dispatch = useDispatch();

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
        <span>
          <button className="px-2 btn btn-link" onClick={() => handleUndo()}>
            <img src={`${paths?.images}/icons/icon-undo.svg`}></img>
          </button>
        </span>
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
        <span>
          <button className="px-2 btn btn-link" onClick={() => handleRedo()}>
            <img src={`${paths?.images}/icons/icon-redo.svg`}></img>
          </button>
        </span>
      </OverlayTrigger>
    </>
  );
};

export default UndoRedoToolbar;
