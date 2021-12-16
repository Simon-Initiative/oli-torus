import { ButtonCommand, ButtonContext } from 'components/editing/toolbar/interfaces';
import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSlate } from 'slate-react';

const buttonContent = (icon: string, description: string | undefined) =>
  icon ? (
    <span className="material-icons">{icon}</span>
  ) : (
    <span className="toolbar-button-text">{description}</span>
  );

interface ToolbarButtonProps {
  key: React.Key;
  icon: string;
  command: ButtonCommand;
  context: ButtonContext;
  description: string;
  style?: string;
  active?: boolean;
  disabled?: boolean;
  position?: 'left' | 'right' | 'top' | 'bottom';
}

export const SimpleButton = (props: ToolbarButtonProps) => {
  const editor = useSlate();

  return (
    <OverlayTrigger
      key={props.description}
      placement={props.position || 'top'}
      delay={{ show: 250, hide: 0 }}
      overlay={(ps) => (
        <Tooltip id={props.icon} {...ps}>
          {props.description}
        </Tooltip>
      )}
    >
      <button
        className={`editor__toolbarButton btn btn-sm ${props.style || ''} ${
          (props.active && 'active') || ''
        }`}
        onMouseDown={(e) => {
          e.preventDefault();
          props.command.execute(props.context, editor);
        }}
      >
        {buttonContent(props.icon, props.description)}
      </button>
    </OverlayTrigger>
  );
};

export const DropdownButton = (props: ToolbarButtonProps) => {
  const editor = useSlate();
  return <span key={props.key}></span>;
  // const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);

  // const onDone = (params: any) => {
  //   setParentPopoverOpen && setParentPopoverOpen(false);
  //   setIsPopoverOpen(false);
  //   command.execute(context, editor, params);
  // };
  // const onCancel = () => {
  //   setParentPopoverOpen && setParentPopoverOpen(false);
  //   setIsPopoverOpen(false);
  // };

  // return (
  //   <Popover.Popover
  //     onClickOutside={(_e) => setIsPopoverOpen(false)}
  //     isOpen={isPopoverOpen}
  //     padding={5}
  //     positions={['right']}
  //     reposition={false}
  //     content={() => <div>{command.obtainParameters?.(context, editor, onDone, onCancel)}</div>}
  //   >
  //     <button
  //       data-container={parentElement || false}
  //       data-toggle="tooltip"
  //       data-placement="top"
  //       title={tooltip}
  //       className={`btn btn-sm btn-light ${style || ''} ${(active && 'active') || ''}`}
  //       onClick={() => setIsPopoverOpen(!isPopoverOpen)}
  //       type="button"
  //     >
  //       {buttonContent(icon, description)}
  //     </button>
  //   </Popover.Popover>
  // );
};

export const Spacer = () => {
  return <span style={{ minWidth: '5px', maxWidth: '5px' }} />;
};
