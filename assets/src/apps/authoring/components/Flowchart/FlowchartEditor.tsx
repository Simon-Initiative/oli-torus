import React, { useCallback, useEffect, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';

import {
  selectAllActivities,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';

import { addFlowchartScreen } from './flowchart-actions/add-screen';
import { deleteFlowchartScreen } from './flowchart-actions/delete-screen';

import {
  buildEdges,
  buildPlaceholders,
  activitiesToNodes,
  buildStartingNode,
} from './flowchart-utils';

import { FlowchartComponent } from './FlowchartComponent';
import {
  FlowchartAddScreenParams,
  FlowchartEventContext,
  FlowchartEventContextProps,
} from './FlowchartEventContext';
import { FlowchartModeOptions } from './FlowchartModeOptions';
import { FlowchartSidebar } from './sidebar/FlowchartSidebar';
import { FlowchartTopToolbar } from './toolbar/FlowchartTopToolbar';
import { changeAppMode, changeEditMode } from '../../store/app/slice';
import { screenTypeToTitle } from './screens/screen-factories';
import { node } from 'webpack';
import { selectSequence } from '../../../delivery/store/features/groups/selectors/deck';

/*
  Flowchart editor deals with translating data to/from the format that the FlowchartComponent requires.
  ex: Converting sequences, activities and rules into nodes and edges and back again.
  The FlowchartComponent deals in flowchart related data.
*/

export const FlowchartEditor = () => {
  const dispatch = useDispatch();

  const activities = useSelector(selectAllActivities);
  const sequence = useSelector(selectSequence);

  console.info('Rendering flowchart', activities, sequence);
  const activityEdges = buildEdges(activities);
  const activityNodes = activitiesToNodes(activities);
  const placeholders = buildPlaceholders(activities);
  const starting = buildStartingNode(activities, sequence);

  const nodes = [starting.node, ...activityNodes, ...placeholders.nodes];
  const edges = [starting.edge, ...activityEdges, ...placeholders.edges];

  useEffect(() => {
    // A cheat-code for going to advanced editor
    const cheat = (e: KeyboardEvent) => {
      console.info(e.key);
      if (e.ctrlKey && e.key === 'F2') {
        dispatch(changeAppMode({ mode: 'expert' }));
      }
    };
    window.addEventListener('keydown', cheat);
    return () => window.removeEventListener('keydown', cheat);
  }, [dispatch]);

  const onAddScreen = useCallback(
    (params: FlowchartAddScreenParams) => {
      const { prevNodeId, nextNodeId, screenType } = params;

      dispatch(
        addFlowchartScreen({
          fromScreenId: prevNodeId,
          toScreenId: nextNodeId,
          screenType,
          title: screenType ? screenTypeToTitle[screenType] : 'New Screen',
        }),
      );
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

  const onScreenEdit = useCallback(() => {
    dispatch(changeEditMode({ mode: 'page' }));
  }, [dispatch]);

  const onEditScreen = useCallback(
    (screenResourceId: number) => {
      dispatch(setCurrentActivityId({ activityId: screenResourceId }));
      onScreenEdit();
    },
    [dispatch, onScreenEdit],
  );

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
        <DndProvider backend={HTML5Backend}>
          <div className="panel-inner">
            <FlowchartModeOptions />
            <FlowchartSidebar />
          </div>

          <div className="flowchart-right">
            <FlowchartTopToolbar />
            <FlowchartComponent nodes={nodes} edges={edges} />
          </div>
        </DndProvider>
      </div>
    </FlowchartEventContext.Provider>
  );
};
