import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import React, { MouseEventHandler } from 'react';
import { classNames } from 'utils/classNames';

export type Props = {
  onClick: MouseEventHandler<HTMLButtonElement>;
  style?: React.CSSProperties;
  className?: string;
  children?: React.ReactNode;
  disabled?: boolean;
  editMode: boolean;
};

export const AuthoringButton: React.FC<Props> = (props: Props) => {
  return (
    <button
      style={props.style}
      className={classNames(['btn', props.className])}
      disabled={props.disabled || !props.editMode}
      type="button"
      onClick={props.onClick}
    >
      {props.children}
    </button>
  );
};

export const AuthoringButtonConnected: React.FC<Omit<Props, 'editMode'>> = (props) => {
  const { editMode } = useAuthoringElementContext();
  return <AuthoringButton {...props} editMode={editMode} />;
};
