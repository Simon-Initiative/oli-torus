import React, { useCallback, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectAllActivities,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';

import { changeAppMode, changeEditMode } from '../../store/app/slice';
import { addFlowchartScreen } from './flowchart-actions/add-screen';
import { deleteFlowchartScreen } from './flowchart-actions/delete-screen';

import { buildEdges, buildPlaceholders, activitiesToNodes } from './flowchart-utils';

import { FlowchartComponent } from './FlowchartComponent';
import {
  FlowchartAddScreenParams,
  FlowchartEventContext,
  FlowchartEventContextProps,
} from './FlowchartEventContext';
import { FlowchartSidebar } from './FlowchartSidebar';
import { FlowchartTopToolbar } from './FlowchartTopToolbar';

/*
  Flowchart editor deals with translating data to/from the format that the FlowchartComponent requires.
  ex: Converting sequences, activities and rules into nodes and edges and back again.
  The FlowchartComponent deals in flowchart related data.
*/

export const FlowchartEditor = () => {
  const dispatch = useDispatch();

  const activities = useSelector(selectAllActivities);

  const activityEdges = buildEdges(activities);
  const activityNodes = activitiesToNodes(activities);
  const placeholders = buildPlaceholders(activities);

  const nodes = [...activityNodes, ...placeholders.nodes];
  const edges = [...activityEdges, ...placeholders.edges];

  const onAddScreen = useCallback(
    (params: FlowchartAddScreenParams) => {
      const { prevNodeId, nextNodeId } = params;
      dispatch(addFlowchartScreen({ fromScreenId: prevNodeId, toScreenId: nextNodeId }));
    },
    [dispatch],
  );

  const onDeleteScreen = useCallback(
    (screenResourceId: number) => {
      dispatch(deleteFlowchartScreen({ screenId: screenResourceId }));
    },
    [dispatch],
  );

  const onSelectScreen = useCallback(
    (screenResourceId: number) => {
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
    },
    [dispatch],
  );

  const onEditScreen = useCallback(
    (screenResourceId: number) => {
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
      dispatch(changeEditMode({ mode: 'page' }));
    },
    [dispatch],
  );

  const onAdvanced = () => {
    dispatch(changeAppMode({ mode: 'expert' }));
  };

  const events: FlowchartEventContextProps = useMemo(
    () => ({
      onAddScreen,
      onDeleteScreen,
      onSelectScreen,
      onEditScreen,
    }),
    [onAddScreen, onDeleteScreen, onEditScreen, onSelectScreen],
  );

  return (
    <FlowchartEventContext.Provider value={events}>
      <div className="flowchart-editor">
        <FlowchartSidebar />
        <div className="flowchart-right">
          <FlowchartTopToolbar onSwitchToAdvancedMode={onAdvanced} />
          <FlowchartComponent nodes={nodes} edges={edges} />
        </div>
      </div>
    </FlowchartEventContext.Provider>
  );
};
