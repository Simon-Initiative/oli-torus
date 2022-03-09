import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import React from 'react';
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
  ariaLabel?: string;
};

export const AuthoringButton: React.FC<Props> = (props: Props) => {
  return (
    <button
      aria-label={props.ariaLabel || ''}
      style={props.style}
      className={classNames('btn', props.className)}
      disabled={props.disabled || !props.editMode}
      type="button"
      onClick={(e) => props.action(e)}
      onKeyPress={(e) => (e.key === 'Enter' ? props.action(e) : null)}
    >
      {props.children}
    </button>
  );
};

export const AuthoringButtonConnected: React.FC<Omit<Props, 'editMode'>> = (props) => {
  const { editMode } = useAuthoringElementContext();
  return <AuthoringButton {...props} editMode={editMode} />;
};
