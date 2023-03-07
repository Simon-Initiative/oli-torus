import React from 'react';
/**
 * It's annoying to pass events from nodes within the flowchart up to the general flowchart editor. where they should be handled
 * This context solves that.
 *
 */

export interface FlowchartAddScreenParams {
  prevNodeId?: number;
  nextNodeId?: number;
}

export interface FlowchartEventContextProps {
  onAddScreen: (p: FlowchartAddScreenParams) => void;
  onDeleteScreen: (nodeId: number) => void;
  onSelectScreen: (nodeId: number) => void;
  onEditScreen: (nodeId: number) => void;
}

export const FlowchartEventContext = React.createContext<FlowchartEventContextProps>({
  onAddScreen: () => {},
  onDeleteScreen: () => {},
  onSelectScreen: () => {},
  onEditScreen: () => {},
});
