import { createAsyncThunk } from '@reduxjs/toolkit';
import { create } from 'data/persistence/activity';
import { cloneT } from '../../../../../utils/common';
import guid from '../../../../../utils/guid';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectAllGroups } from '../../../../delivery/store/features/groups/slice';

import { saveActivity } from '../../../store/activities/actions/saveActivity';
import {
  createActivityTemplate,
  IActivityTemplate,
} from '../../../store/activities/templates/activity';
import {
  selectActivityTypes,
  selectProjectSlug,
  selectAppMode,
  ActivityRegistration,
} from '../../../store/app/slice';
import { addSequenceItem } from '../../../store/groups/layouts/deck/actions/addSequenceItem';
import { setCurrentActivityFromSequence } from '../../../store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { savePage } from '../../../store/page/actions/savePage';
import { selectState as selectPageState } from '../../../store/page/slice';
import { AuthoringRootState } from '../../../store/rootReducer';
import {
  AuthoringFlowchartScreenData,
  createAlwaysGoToPath,
  createEndOfActivityPath,
  hasDestinationPath,
  setGoToAlwaysPath,
  setUnknownPathDestination,
} from '../flowchart-path-utils';

interface AddFlowchartScreenPayload {
  fromScreenId?: number;
  toScreenId?: number;
  title?: string;
}

/**
 * Logic for adding a screen to the flowchart view of a lesson. This only works on appState.applicationMode === 'flowchart'
 *
 *  Assumptions:
 *      - Only a single group
 *      - No layers / parent screens
 */
export const addFlowchartScreen = createAsyncThunk(
  `${ActivitiesSlice}/addFlowchartScreen`,
  async (payload: AddFlowchartScreenPayload, { dispatch, getState }) => {
    try {
      const rootState = getState() as AuthoringRootState;
      const appMode = selectAppMode(rootState);
      if (appMode !== 'flowchart') {
        throw new Error('addFlowchartScreen can only be called when appMode is flowchart');
      }
      const projectSlug = selectProjectSlug(rootState);
      const activityTypes = selectActivityTypes(rootState);
      const currentLesson = selectPageState(rootState);
      const sequence = selectSequence(rootState);

      const group = selectAllGroups(rootState)[0];

      const { title = 'New Screen' } = payload;

      const activity: IActivityTemplate = {
        ...createActivityTemplate(),
        title,
        width: currentLesson.custom.defaultScreenWidth,
        height: currentLesson.custom.defaultScreenHeight,
      };

      const flowchartData: AuthoringFlowchartScreenData = {
        paths: [],
      };
      activity.model.authoring.flowchart = flowchartData;

      if (payload.toScreenId) {
        flowchartData.paths.push(createAlwaysGoToPath(payload.toScreenId));
      } else {
        flowchartData.paths.push(createEndOfActivityPath());
      }

      const createResults = await create(
        projectSlug,
        activity.typeSlug,
        activity.model,
        activity.objectives.attached,
      );

      if (createResults.result === 'failure') {
        // TODO - handle error
        return;
      }

      if (payload.fromScreenId) {
        // In this case, we need to edit that other screen's paths so it goes here.

        const fromScreen = cloneT(selectActivityById(rootState, payload.fromScreenId));

        if (fromScreen) {
          if (hasDestinationPath(fromScreen)) {
            // If the "from" doesn't have any other paths, we can use an always-path, but if it does, we default
            // to an unknwon-path for the user to fill in later.
            setUnknownPathDestination(fromScreen, createResults.resourceId);
          } else {
            setGoToAlwaysPath(fromScreen, createResults.resourceId);
          }
          // TODO - these two should be a single operation?
          await dispatch(upsertActivity({ activity: fromScreen }));
          dispatch(saveActivity({ activity: fromScreen, undoable: false, immediate: true }));
        }
      }

      // Copied this logic from createNew.ts, this absurdity needs to be understood and fixed
      activity.activity_id = createResults.resourceId;
      activity.activityId = activity.activity_id;
      activity.resourceId = activity.activity_id;
      activity.activitySlug = createResults.revisionSlug;

      activity.activityType = activityTypes.find(
        (type: ActivityRegistration) => type.slug === activity.typeSlug,
      );

      const sequenceEntry: any = {
        type: 'activity-reference',
        resourceId: activity.resourceId,
        activitySlug: activity.activitySlug,
        custom: {
          isLayer: false,
          isBank: false,
          layerRef: null,
          sequenceId: `${activity.activitySlug}_${guid()}`,
          sequenceName: title,
        },
      };

      const reduxActivity = {
        id: activity.resourceId,
        resourceId: activity.resourceId,
        activitySlug: activity.activitySlug,
        activityType: activity.activityType,
        content: { ...activity.model, authoring: undefined },
        authoring: activity.model.authoring,
        title,
        tags: [],
      };
      dispatch(saveActivity({ activity: reduxActivity, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: reduxActivity }));

      await dispatch(
        addSequenceItem({
          sequence: sequence,
          item: sequenceEntry,
          group,
        }),
      );

      dispatch(setCurrentActivityFromSequence(sequenceEntry.custom.sequenceId));

      // will write the current groups
      await dispatch(savePage({ undoable: false }));
      return activity;
    } catch (e) {
      console.error(e);
      throw e;
    }
  },
);
