import React, { useCallback, useEffect, useMemo } from 'react';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { useDispatch, useSelector } from 'react-redux';
import {
  selectAllActivities,
  selectCurrentActivityId,
  setCurrentActivityId,
} from '../../../delivery/store/features/activities/slice';
import { changeAppMode, changeEditMode } from '../../store/app/slice';
import { FlowchartComponent } from './FlowchartComponent';
import { FlowchartErrorDisplay } from './FlowchartErrorMessages';
import {
  FlowchartAddScreenParams,
  FlowchartEventContext,
  FlowchartEventContextProps,
} from './FlowchartEventContext';
import { FlowchartModeOptions } from './FlowchartModeOptions';
import { addFlowchartScreen } from './flowchart-actions/add-screen';
import { deleteFlowchartScreen } from './flowchart-actions/delete-screen';
import { activitiesToNodes, buildEdges } from './flowchart-utils';
import { screenTypeToTitle } from './screens/screen-factories';
import { FlowchartSidebar } from './sidebar/FlowchartSidebar';
import { FlowchartTopToolbar } from './toolbar/FlowchartTopToolbar';

/*
  Flowchart editor deals with translating data to/from the format that the FlowchartComponent requires.
  ex: Converting sequences, activities and rules into nodes and edges and back again.
  The FlowchartComponent deals in flowchart related data.
*/

interface FlowchartEditorProps {
  sidebarExpanded?: boolean;
}

export const FlowchartEditor: React.FC<FlowchartEditorProps> = ({ sidebarExpanded }) => {
  const dispatch = useDispatch();

  const activities = useSelector(selectAllActivities);
  const currentActivityId = useSelector(selectCurrentActivityId);

  const edges = useMemo(() => buildEdges(activities), [activities]);
  const nodes = useMemo(() => activitiesToNodes(activities), [activities]);
  useEffect(() => {
    // A cheat-code for going to advanced editor
    const cheat = (e: KeyboardEvent) => {
      if (e.ctrlKey && e.key === 'F2') {
        dispatch(changeAppMode({ mode: 'expert' }));
      }
    };
    window.addEventListener('keydown', cheat);
    return () => window.removeEventListener('keydown', cheat);
  }, [dispatch]);

  const onPageEditMode = useCallback(() => {
    if (!currentActivityId) return;
    dispatch(changeEditMode({ mode: 'page' }));
  }, [currentActivityId, dispatch]);

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
      <div className={`flowchart-editor ${!sidebarExpanded ? '' : 'ml-[135px]'}`}>
        <DndProvider backend={HTML5Backend}>
          <div className="flowchart-left">
            <FlowchartModeOptions activeMode="flowchart" onPageEditMode={onPageEditMode} />
            <FlowchartSidebar />
          </div>

          <div className="flowchart-right">
            <FlowchartTopToolbar />
            {useMemo(
              () => (
                <FlowchartComponent nodes={nodes} edges={edges} />
              ),
              [nodes, edges],
            )}
          </div>
        </DndProvider>
      </div>
      <FlowchartErrorDisplay />
    </FlowchartEventContext.Provider>
  );
};
