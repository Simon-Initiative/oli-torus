import React from 'react';
import { useSlate } from 'slate-react';
import { ToolbarButton, DropdownToolbarButton } from 'components/editing/toolbars/common';
export const FormattingToolbar = (props) => {
    const editor = useSlate();
    const buttonGroups = props.commandDescs.reduce((acc, cmdDescs) => {
        const buttons = cmdDescs.reduce((acc, cmdDesc) => {
            if (!cmdDesc.command.precondition(editor)) {
                return acc;
            }
            const description = cmdDesc.description(editor);
            const shared = {
                style: 'btn-dark',
                active: cmdDesc.active && cmdDesc.active(editor),
                key: description,
                description,
                icon: cmdDesc.icon(editor),
                command: cmdDesc.command,
                context: props.commandContext,
                tooltip: description,
                position: 'top',
            };
            return acc.concat([
                cmdDesc.command.obtainParameters === undefined ? (<ToolbarButton {...shared}/>) : (<DropdownToolbarButton {...shared}/>),
            ]);
        }, []);
        return buttons.length > 0 ? acc.concat([buttons]) : acc;
    }, []);
    return (<React.Fragment>
      {buttonGroups.reduce((acc, buttons, i, buttonGroups) => {
            if (i === buttonGroups.length - 1) {
                return acc.concat(buttons);
            }
            return acc
                .concat(buttons)
                .concat([<div key={'spacer-' + i} className="button-separator"></div>]);
        }, [])}
    </React.Fragment>);
};
//# sourceMappingURL=Toolbar.jsx.map