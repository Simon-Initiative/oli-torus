import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useDispatch, useSelector } from 'react-redux';
import { redo } from 'apps/authoring/store/history/actions/redo';
import { undo } from 'apps/authoring/store/history/actions/undo';
import { selectHasRedo, selectHasUndo } from 'apps/authoring/store/history/slice';
import { useKeyDown } from 'hooks/useKeyDown';
import { selectPaths, selectReadOnly } from '../../store/app/slice';

const UndoRedoToolbar: React.FC = () => {
  const paths = useSelector(selectPaths);
  const dispatch = useDispatch();

  const hasRedo = useSelector(selectHasRedo);
  const hasUndo = useSelector(selectHasUndo);
  const isReadOnly = useSelector(selectReadOnly);

  const handleUndo = () => {
    if (isReadOnly) {
      return;
    }
    dispatch(undo(null));
  };

  const handleRedo = () => {
    if (isReadOnly) {
      return;
    }
    dispatch(redo(null));
  };

  useKeyDown(
    (ctrlKey, metaKey, shiftKey) => {
      if ((ctrlKey || metaKey) && !shiftKey) {
        handleUndo();
      }
    },
    ['KeyZ'],
    { ctrlKey: true },
  );
  useKeyDown(
    (ctrlKey, metaKey) => {
      if (ctrlKey && !metaKey) handleRedo();
    },
    ['KeyY'],
    { ctrlKey: true },
  );
  useKeyDown(
    (ctrlKey, metaKey, shiftKey) => {
      if ((ctrlKey || metaKey) && shiftKey) {
        handleRedo();
      }
    },
    ['KeyZ'],
    { ctrlKey: true },
  );
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
          disabled={isReadOnly || !hasUndo}
          style={{
            opacity: isReadOnly || !hasUndo ? '0.25' : '1',
            pointerEvents: isReadOnly || !hasUndo ? 'none' : 'auto',
          }}
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
          disabled={isReadOnly || !hasRedo}
          style={{
            opacity: isReadOnly || !hasRedo ? '0.25' : '1',
            pointerEvents: isReadOnly || !hasRedo ? 'none' : 'auto',
          }}
        >
          <img src={`${paths?.images}/icons/icon-redo.svg`} className="icon-redo icon-history" />
        </button>
      </OverlayTrigger>
    </>
  );
};

export default UndoRedoToolbar;
