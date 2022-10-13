import React, { useCallback } from 'react';
import * as ContentModel from '../../data/content/model/elements/types';
import { dispatch, makeCommandButtonEvent, Registry } from '../../data/events';

interface Props {
  commandButton: ContentModel.CommandButton;
  children: React.ReactNode;
  editorAttributes?: any;
  disableCommand?: boolean; // For edit-mode
}

export const CommandButton: React.FC<Props> = ({
  commandButton,
  children,
  disableCommand = false,
  editorAttributes = null,
}) => {
  const onClick = useCallback(() => {
    const event = makeCommandButtonEvent({
      forId: commandButton.target,
      message: commandButton.message,
    });
    disableCommand || dispatch(Registry.CommandButtonClick, event);
  }, [commandButton.message, commandButton.target, disableCommand]);

  const cssClass =
    commandButton.style === 'button'
      ? 'btn btn-primary command-button'
      : 'btn btn-link command-button';

  return (
    <span onClick={onClick} className={cssClass} {...editorAttributes}>
      {children}
    </span>
  );
};
