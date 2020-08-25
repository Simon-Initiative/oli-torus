import React from 'react';
import { useSlate } from 'slate-react';
import { CommandContext } from '../editors/interfaces';
import { CommandDesc } from '../commands/interfaces';
import { ToolbarButton } from 'components/editor/toolbars/common';

export type HoveringToolbarProps = {
  commandContext: CommandContext;
  commandDescs: CommandDesc[][];
};
export const HoveringToolbar = (props: HoveringToolbarProps) => {
  const editor = useSlate();

  const isLastInList = (array: any[], index: number) => index === array.length - 1;

  return (
    <div className="hovering-toolbar">
      <div className="btn-group btn-group-sm" role="group">
        {props.commandDescs.map((cmdDescs: CommandDesc[], cmdDescsIndex) => {
          const buttons = cmdDescs.map((cmdDesc) => {
            if (!cmdDesc.command.precondition(editor)) {
              return null;
            }
            const description = cmdDesc.description(editor);

            return <ToolbarButton
              disabled={!cmdDesc.command.precondition(editor)}
              style="btn-dark"
              active={cmdDesc.active && cmdDesc.active(editor)}
              key={description}
              description={description}
              icon={cmdDesc.icon(editor)}
              command={cmdDesc.command}
              context={props.commandContext}
            />;
          });

          const buttonSeparator =
            <div key={'spacer-' + cmdDescsIndex} className="button-separator"></div>;

          return isLastInList(props.commandDescs, cmdDescsIndex)
            || buttons.filter(x => x).length === 0
            ? buttons.filter(x => x)
            : buttons.filter(x => x).concat(buttonSeparator);
        })}
      </div>
    </div>
  );
};
