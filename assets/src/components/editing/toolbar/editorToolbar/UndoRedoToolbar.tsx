import React, { useMemo } from 'react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { CommandButton } from '../buttons/CommandButton';

export const UndoRedoToolbar = () => {
  const undoDesc = useMemo(
    () =>
      createButtonCommandDesc({
        icon: <i className="fa fa-rotate-left"></i>,
        description: 'Undo',
        execute: (_context, editor, src: string) => {
          editor.undo();
        },
      }),
    [],
  );

  const redoDesc = useMemo(
    () =>
      createButtonCommandDesc({
        icon: <i className="fa fa-rotate-right"></i>,
        description: 'Redo',
        execute: (_context, editor, src: string) => {
          editor.redo();
        },
      }),
    [],
  );

  return (
    <Toolbar.Group>
      <CommandButton description={undoDesc} />
      <CommandButton description={redoDesc} />
    </Toolbar.Group>
  );
};
