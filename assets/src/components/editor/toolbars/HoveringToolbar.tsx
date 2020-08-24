import React, { useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { useSlate, ReactEditor } from 'slate-react';
import { CommandContext } from '../editors/interfaces';
import { CommandDesc } from '../commands/interfaces';
import { showToolbar, isToolbarHidden, hideToolbar, ToolbarButton } from 'components/editor/toolbars/common';
import { positionFormatting } from 'components/editor/toolbars/formatting/utils';

function hoveringAreEqual(prevProps: HoveringToolbarProps, nextProps: HoveringToolbarProps) {
  return prevProps.commandContext === nextProps.commandContext;
}

export type HoveringToolbarProps = {
  commandContext: CommandContext;
  commandDescs: CommandDesc[][];
  // shouldHideToolbar: (editor: ReactEditor) => boolean;
};
export const HoveringToolbar = (props: HoveringToolbarProps) => {
  const editor = useSlate();

  const isLastInList = (array: any[], index: number) => index === array.length - 1;

  return (
    <div className="hovering-toolbar">
      <div className="btn-group btn-group-sm" role="group">
        {props.commandDescs.map((cmdDescs: CommandDesc[], cmdDescsIndex) => {
          const buttons = cmdDescs.map((cmdDesc) => {
            const icon = cmdDesc.icon(editor);
            const description = cmdDesc.description(editor);

            const active = cmdDesc.active
              ? cmdDesc.active(editor)
              : false;

            return <ToolbarButton
              disabled={!cmdDesc.command.precondition(editor, [])}
              style="btn-dark"
              active={active}
              key={description}
              description={description}
              icon={icon}
              command={cmdDesc.command}
              context={props.commandContext}
            />;
          });

          const buttonSeparator =
            <div key={'spacer-' + cmdDescsIndex} className="button-separator"></div>;

          return isLastInList(props.commandDescs, cmdDescsIndex)
            || buttons.filter(x => x).length === 0
            ? buttons
            : buttons.concat(buttonSeparator);
        })}
      </div>
    </div>
  );
};


/*

*/
