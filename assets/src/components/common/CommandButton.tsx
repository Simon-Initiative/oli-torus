import React, { useCallback, useEffect, useMemo, useState } from 'react';
import * as ContentModel from '../../data/content/model/elements/types';
import { Registry, dispatch, makeCommandButtonEvent } from '../../data/events';
import { selectCurrentAndNextToggleState } from './commandButtonToggle';

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
  const toggleStates =
    commandButton.toggleStates && commandButton.toggleStates.length > 0
      ? commandButton.toggleStates
      : null;

  const initialTitleFromChildren = useMemo(() => {
    const toText = (node: React.ReactNode): string => {
      if (typeof node === 'string' || typeof node === 'number') return String(node);
      if (!node) return '';
      if (Array.isArray(node)) return node.map(toText).join('');
      if (React.isValidElement<{ children?: React.ReactNode }>(node)) {
        return toText(node.props.children);
      }
      return '';
    };
    return toText(children).trim();
  }, [children]);

  const [currentTitle, setCurrentTitle] = useState(initialTitleFromChildren);

  useEffect(() => {
    if (toggleStates) {
      setCurrentTitle(initialTitleFromChildren || toggleStates[0].title);
    }
  }, [toggleStates, initialTitleFromChildren]);

  const onClick = useCallback(
    (clickEvent: React.MouseEvent) => {
      clickEvent.preventDefault(); // Fixes MER-1496 - command buttons would submit an MCQ question.

      let message = commandButton.message;

      if (toggleStates) {
        const { currentState, nextState } = selectCurrentAndNextToggleState(
          toggleStates,
          currentTitle,
        );
        message = currentState.message;
        if (!disableCommand) {
          setCurrentTitle(nextState.title);
        }
      }

      const event = makeCommandButtonEvent({
        forId: commandButton.target,
        message,
      });
      disableCommand || dispatch(Registry.CommandButtonClick, event);
    },
    [commandButton.message, commandButton.target, currentTitle, toggleStates, disableCommand],
  );

  const cssClass =
    commandButton.style === 'button'
      ? 'btn btn-primary command-button'
      : 'btn btn-link command-button';
  const editorLayoutClass = editorAttributes ? ' inline-flex items-center' : '';

  const showToggleTitle = toggleStates && !editorAttributes;
  const accessibleTitle = toggleStates ? currentTitle || toggleStates[0].title : undefined;

  return (
    <button
      type="button"
      onClick={onClick}
      className={`${cssClass}${editorLayoutClass}`}
      aria-label={accessibleTitle}
      aria-live={toggleStates ? 'polite' : undefined}
      aria-atomic={toggleStates ? 'true' : undefined}
      {...editorAttributes}
    >
      {showToggleTitle ? currentTitle || toggleStates[0].title : children}
    </button>
  );
};
