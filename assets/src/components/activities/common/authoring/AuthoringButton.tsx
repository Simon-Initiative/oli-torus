import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { classNames } from 'utils/classNames';

export type Props = {
  action: (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent> | React.KeyboardEvent<HTMLButtonElement>,
  ) => void;
  style?: React.CSSProperties;
  className?: string;
  children?: React.ReactNode;
  disabled?: boolean;
  editMode: boolean;
  mode?: 'authoring' | 'instructor_preview';
  ariaLabel?: string;
};

export const AuthoringButton: React.FC<Props> = (props: Props) => {
  const isDisabled = props.disabled || !props.editMode || props.mode === 'instructor_preview';

  return (
    <button
      aria-label={props.ariaLabel || ''}
      style={props.style}
      className={classNames('btn', props.className)}
      disabled={isDisabled}
      type="button"
      onClick={(e) => props.action(e)}
      onKeyPress={(e: any) => (e.key === 'Enter' ? props.action(e) : null)}
    >
      {props.children}
    </button>
  );
};

export const AuthoringButtonConnected: React.FC<Omit<Props, 'editMode' | 'mode'>> = (props) => {
  const { editMode, mode } = useAuthoringElementContext();
  return <AuthoringButton {...props} editMode={editMode} mode={mode} />;
};
