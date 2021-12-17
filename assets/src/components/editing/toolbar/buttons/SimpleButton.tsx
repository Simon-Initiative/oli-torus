import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSlate } from 'slate-react';
import React from 'react';
import { buttonContent, ToolbarButtonProps } from 'components/editing/toolbar/buttons/common';
import { OverlayInjectedProps } from 'react-bootstrap/esm/Overlay';
import { classNames } from 'utils/classNames';

export const SimpleButton = (props: ToolbarButtonProps) => {
  const editor = useSlate();

  const onMouseDown = React.useCallback(
    (e: React.MouseEvent<HTMLButtonElement, MouseEvent>) => {
      e.preventDefault();
      if (props.command.obtainParameters) {
        return;
      }
      props.command.execute(props.context, editor);
    },
    [props.command.execute, editor],
  );

  const tooltip = React.useCallback(
    (overlayProps: OverlayInjectedProps) => {
      if (!props.command.precondition(editor)) return null;
      if (props.command.obtainParameters)
        return (
          <div {...overlayProps}>
            {props.command.obtainParameters(
              props.context,
              editor,
              (params) => props.command.execute(props.context, editor, params),
              () => {},
            )}
          </div>
        );
      return (
        <Tooltip id={props.icon} {...overlayProps}>
          {props.description}
        </Tooltip>
      );
    },
    [props.icon, props.description],
  );

  const content = React.useMemo(
    () => buttonContent(props.icon, props.description),
    [props.icon, props.description],
  );

  return (
    <OverlayTrigger
      key={props.description}
      placement={props.position || 'top'}
      delay={{ show: 250, hide: 0 }}
      overlay={tooltip}
    >
      <button
        disabled={!props.command.precondition(editor)}
        className={classNames([
          'editor__toolbarButton',
          'btn',
          'btn-xs',
          props.style,
          props.active && 'active',
        ])}
        onMouseDown={onMouseDown}
      >
        {content}
      </button>
    </OverlayTrigger>
  );
};
