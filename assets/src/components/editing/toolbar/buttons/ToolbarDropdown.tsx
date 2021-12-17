import { buttonContent, ToolbarButtonProps } from 'components/editing/toolbar/buttons/common';
import React from 'react';
import { Tooltip, OverlayTrigger, DropdownButton, Dropdown } from 'react-bootstrap';
import { OverlayInjectedProps } from 'react-bootstrap/esm/Overlay';
import { useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';

export const ToolbarDropdown = (props: ToolbarButtonProps) => {
  const editor = useSlate();

  const onMouseDown = React.useCallback(
    (e: React.MouseEvent<HTMLButtonElement, MouseEvent>) => {
      e.preventDefault();
      // props.command.obtainParameters?.(
      //   props.context,
      //   editor,
      //   (params) => props.command.execute(props.context, editor, params),
      //   () => {},
      // );
    },
    [props.command, editor],
  );

  const tooltip = React.useCallback(
    (overlayProps: OverlayInjectedProps) => {
      return (
        <Tooltip id={props.icon} {...overlayProps}>
          {props.description}
        </Tooltip>
      );
    },
    [props.icon, props.description],
  );

  const overlay = React.useCallback((overlayProps: OverlayInjectedProps) => {
    return (
      <Tooltip id={props.icon} {...overlayProps}>
        {props.command.obtainParameters?.(
          props.context,
          editor,
          (params) => props.command.execute(props.context, editor, params),
          () => {},
        )}
      </Tooltip>
    );
  }, []);

  const content = React.useMemo(
    () => buttonContent(props.icon, props.description),
    [props.icon, props.description],
  );

  return (
    <OverlayTrigger
      key={props.description}
      placement={props.position || 'top'}
      delay={{ show: 250, hide: 0 }}
      overlay={overlay}
    >
      <DropdownButton title={props.description}>
        <Dropdown.Item
          disabled={!props.command.precondition(editor)}
          className={classNames(['editor__toolbarButton', 'btn', 'btn-xs', props.style])}
          onMouseDown={onMouseDown}
        >
          {content}
        </Dropdown.Item>
      </DropdownButton>
    </OverlayTrigger>
  );

  // const onDone = (params: any) => {
  //   setParentPopoverOpen && setParentPopoverOpen(false);
  //   setIsPopoverOpen(false);
  //   command.execute(context, editor, params);
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
  // );
};
