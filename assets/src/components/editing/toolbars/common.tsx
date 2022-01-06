import React from 'react';
import * as Popover from 'react-tiny-popover';
import { useSlate } from 'slate-react';
import { Command, CommandContext } from '../commands/interfaces';

export function hideToolbar(el: HTMLElement) {
  el.style.display = 'none';
}

export function showToolbar(el: HTMLElement) {
  el.style.display = 'block';
}

const buttonContent = (icon: string, description: string | undefined) =>
  icon ? (
    <span className="material-icons">{icon}</span>
  ) : (
    <span className="toolbar-button-text">{description}</span>
  );

interface ToolbarButtonProps {
  icon: string;
  command: Command;
  context: CommandContext;
  description?: string;
  tooltip?: string;
  style?: string;
  active?: boolean;
  disabled?: boolean;
  position?: 'left' | 'right' | 'top' | 'bottom';
  setParentPopoverOpen?: (b: boolean) => void;
  parentElement?: string;
  setContent?: React.Dispatch<React.SetStateAction<JSX.Element>>;
}

export const ToolbarButton = ({
  icon,
  command,
  style,
  context,
  active,
  description,
  setParentPopoverOpen,
  tooltip,
  position,
  parentElement,
}: ToolbarButtonProps) => {
  const editor = useSlate();

  return (
    <button
      data-container={parentElement && `#${parentElement}`}
      data-toggle="tooltip"
      ref={(r) => ($(r as any) as any).tooltip()}
      data-placement={position === undefined ? 'right' : position}
      title={tooltip}
      className={`btn btn-sm btn-light ${style || ''} ${(active && 'active') || ''}`}
      onClick={(_e) => {
        setParentPopoverOpen?.(false);
        command.execute(context, editor);
      }}
    >
      {buttonContent(icon, description)}
    </button>
  );
};

export const DropdownToolbarButton = (props: ToolbarButtonProps) => {
  const editor = useSlate();
  // const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);

  const onDone = (params: any) => {
    props.setParentPopoverOpen?.(false);
    // setIsPopoverOpen(false);
    props.command.execute(props.context, editor, params);
  };
  const onCancel = () => {
    props.setParentPopoverOpen?.(false);
    // setIsPopoverOpen(false);
  };

  return (
    // <Popover.Popover
    //   onClickOutside={(_e) => setIsPopoverOpen(false)}
    //   isOpen={isPopoverOpen}
    //   padding={5}
    //   positions={['right']}
    //   reposition={false}
    //   content={() => <div>{}</div>}
    // >
    <button
      data-container={props.parentElement && `#${props.parentElement}`}
      data-toggle="tooltip"
      ref={(r) => ($(r as any) as any).tooltip()}
      data-placement="top"
      title={props.tooltip}
      className={`btn btn-sm btn-light ${props.style || ''} ${(props.active && 'active') || ''}`}
      onClick={(_e) => {
        _e.stopPropagation();
        props.setContent?.(
          props.command.obtainParameters?.(props.context, editor, onDone, onCancel) || (
            <span></span>
          ),
        );
      }}
    >
      {buttonContent(props.icon, props.description)}
    </button>
    // </Popover.Popover>
  );
};

export const Spacer = () => {
  return <span style={{ minWidth: '5px', maxWidth: '5px' }} />;
};
