import { createAsyncThunk } from '@reduxjs/toolkit';
import { create } from 'data/persistence/activity';
import { cloneT } from '../../../../../utils/common';
import guid from '../../../../../utils/guid';
import {
  selectActivityById,
  selectAllActivities,
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
import { FlowchartSlice } from '../../../store/flowchart/name';
import { addSequenceItem } from '../../../store/groups/layouts/deck/actions/addSequenceItem';
import { setCurrentActivityFromSequence } from '../../../store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { savePage } from '../../../store/page/actions/savePage';
import { selectState as selectPageState } from '../../../store/page/slice';
import { AuthoringRootState } from '../../../store/rootReducer';
import {
  hasDestinationPath,
  setGoToAlwaysPath,
  setUnknownPathDestination,
} from '../paths/path-utils';
import { sortScreens } from '../screens/screen-utils';
import { replaceIds } from '../template-utils';

interface DuplicateFlowchartScreenPayload {
  screenId: number;
}

/**
 * Logic for adding a screen to the flowchart view of a lesson. This only works on appState.applicationMode === 'flowchart'
 *
 *  Assumptions:
 *      - Only a single group
 *      - No layers / parent screens
 */
export const duplicateFlowchartScreen = createAsyncThunk(
  `${FlowchartSlice}/duplicateFlowchartScreen`,
  async (payload: DuplicateFlowchartScreenPayload, { dispatch, getState }) => {
    try {
      const rootState = getState() as AuthoringRootState;
      const appMode = selectAppMode(rootState);
      if (appMode !== 'flowchart') {
        throw new Error('addFlowchartScreen can only be called when appMode is flowchart');
      }
      const projectSlug = selectProjectSlug(rootState);
      const activityTypes = selectActivityTypes(rootState);
      const sequence = selectSequence(rootState);
      const otherActivities = selectAllActivities(rootState);
      const otherActivityNames = otherActivities.map((a) => a.title || '');

      const group = selectAllGroups(rootState)[0];

      const originalScreen = selectActivityById(rootState, payload.screenId);

      if (!originalScreen) {
        console.warn('Could not find screen to duplicate');
        return;
      }

      const targetTitle = 'Copy of ' + (originalScreen.title || 'screen');
      const title = clearTitle(targetTitle, otherActivityNames);

      const activity: IActivityTemplate = createActivityTemplate();
      //activity.model = cloneT(originalScreen);

      const idMap: Record<string, string> = {};

      const newParts = originalScreen.authoring?.parts?.map(replaceIds(idMap)) || [];
      const newPartsLayout = originalScreen.content?.partsLayout?.map(replaceIds(idMap)) || [];

      activity.model.partsLayout = newPartsLayout;
      activity.model.authoring.parts = newParts;
      activity.model.authoring.flowchart = {
        paths: [],
        screenType: originalScreen.authoring?.flowchart?.screenType,
        templateApplied: originalScreen.authoring?.flowchart?.templateApplied,
      };

      activity.title = title;

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

      const getLastScreenId = (): number | undefined => {
        const orderedScreens = sortScreens(otherActivities, sequence);
        if (orderedScreens.length === 0) {
          return undefined;
        }
        return orderedScreens[orderedScreens.length - 1].resourceId;
      };

      // If a from-screen isn't specified, then tack it on to the very end of the lesson.
      const fromScreenId = getLastScreenId();

      if (fromScreenId) {
        // In this case, we need to edit that other screen's paths so it goes here.
        const fromScreen = cloneT(selectActivityById(rootState, fromScreenId));

        if (fromScreen) {
          if (hasDestinationPath(fromScreen)) {
            // If the "from" doesn't have any other paths, we can use an always-path, but if it does, we default
            // to an unknown-path for the user to fill in later.
            setUnknownPathDestination(fromScreen, createResults.resourceId);
          } else {
            setGoToAlwaysPath(fromScreen, createResults.resourceId);
          }

          // TODO - these two should be a single operation?
          dispatch(saveActivity({ activity: fromScreen, undoable: false, immediate: true }));
          await dispatch(upsertActivity({ activity: fromScreen }));
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

      // TODO - figure out initial rules generation here.
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

const clearTitle = (title: string, otherActivityNames: string[], level = 0): string => {
  const newTitle = level === 0 ? title : `${title} (${level})`;
  if (otherActivityNames.includes(newTitle)) {
    return clearTitle(title, otherActivityNames, level + 1);
  }
  return newTitle;
};
