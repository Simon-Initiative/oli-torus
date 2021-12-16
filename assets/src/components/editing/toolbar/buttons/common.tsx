import { ButtonCommand, ButtonContext } from 'components/editing/toolbar/interfaces';
import React from 'react';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { useSlate } from 'slate-react';

export const buttonContent = (icon: string, description: string | undefined) =>
  icon ? (
    <span className="material-icons">{icon}</span>
  ) : (
    <span className="toolbar-button-text">{description}</span>
  );

export interface ToolbarButtonProps {
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
