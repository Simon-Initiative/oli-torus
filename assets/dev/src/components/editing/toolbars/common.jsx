import React from 'react';
import * as Popover from 'react-tiny-popover';
import { useSlate } from 'slate-react';
export function hideToolbar(el) {
    el.style.display = 'none';
}
export function showToolbar(el) {
    el.style.display = 'block';
}
const buttonContent = (icon, description) => icon ? (<span className="material-icons">{icon}</span>) : (<span className="toolbar-button-text">{description}</span>);
export const ToolbarButton = ({ icon, command, style, context, active, description, setParentPopoverOpen, tooltip, position, parentElement, }) => {
    const editor = useSlate();
    return (<button data-container={parentElement && `#${parentElement}`} data-toggle="tooltip" ref={(r) => $(r).tooltip()} data-placement={position === undefined ? 'right' : position} title={tooltip} className={`btn btn-sm btn-light ${style || ''} ${(active && 'active') || ''}`} onClick={(_e) => {
            setParentPopoverOpen && setParentPopoverOpen(false);
            command.execute(context, editor);
        }}>
      {buttonContent(icon, description)}
    </button>);
};
export const DropdownToolbarButton = ({ icon, command, style, context, active, description, setParentPopoverOpen, tooltip, parentElement, }) => {
    const editor = useSlate();
    const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);
    const onDone = (params) => {
        setParentPopoverOpen && setParentPopoverOpen(false);
        setIsPopoverOpen(false);
        command.execute(context, editor, params);
    };
    const onCancel = () => {
        setParentPopoverOpen && setParentPopoverOpen(false);
        setIsPopoverOpen(false);
    };
    return (<Popover.Popover onClickOutside={(_e) => setIsPopoverOpen(false)} isOpen={isPopoverOpen} padding={5} positions={['right']} reposition={false} content={() => { var _a; return <div>{(_a = command.obtainParameters) === null || _a === void 0 ? void 0 : _a.call(command, context, editor, onDone, onCancel)}</div>; }}>
      <button data-container={parentElement || false} data-toggle="tooltip" data-placement="top" title={tooltip} className={`btn btn-sm btn-light ${style || ''} ${(active && 'active') || ''}`} onClick={() => setIsPopoverOpen(!isPopoverOpen)} type="button">
        {buttonContent(icon, description)}
      </button>
    </Popover.Popover>);
};
export const Spacer = () => {
    return <span style={{ minWidth: '5px', maxWidth: '5px' }}/>;
};
//# sourceMappingURL=common.jsx.map