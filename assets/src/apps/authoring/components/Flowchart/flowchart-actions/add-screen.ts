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
  IActivityTemplate,
  createActivityTemplate,
} from '../../../store/activities/templates/activity';
import { createSimpleText } from '../../../store/activities/templates/simpleText';
import {
  ActivityRegistration,
  selectActivityTypes,
  selectAppMode,
  selectProjectSlug,
} from '../../../store/app/slice';
import { reportAPIError } from '../../../store/flowchart/flowchart-slice';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { addSequenceItem } from '../../../store/groups/layouts/deck/actions/addSequenceItem';
import { setCurrentActivityFromSequence } from '../../../store/groups/layouts/deck/actions/setCurrentActivityFromSequence';
import { savePage } from '../../../store/page/actions/savePage';
import { selectState as selectPageState } from '../../../store/page/slice';
import { AuthoringRootState } from '../../../store/rootReducer';
import {
  createAlwaysGoToPath,
  createEndOfActivityPath,
  createExitPath,
} from '../paths/path-factories';
import { QuestionTypeMapping } from '../paths/path-options';
import { AuthoringFlowchartScreenData } from '../paths/path-types';
import {
  hasDestinationPath,
  removeDestinationPath,
  setGoToAlwaysPath,
  setUnknownPathDestination,
} from '../paths/path-utils';
import { getActivitySlugFromScreenResourceId } from '../rules/create-generic-rule';
import { getFirstScreenInSequence, sortScreens } from '../screens/screen-utils';

interface AddFlowchartScreenPayload {
  fromScreenId?: number;
  toScreenId?: number;
  title?: string;
  screenType?: string;
  skipPathToNewScreen?: boolean;
}

/**
 * Logic for adding a screen to the flowchart view of a lesson. This only works on appState.applicationMode === 'flowchart'
 *
 *  Assumptions:
 *      - Only a single group
 *      - No layers / parent screens
 */
export const addFlowchartScreen = createAsyncThunk(
  `${FlowchartSlice}/addFlowchartScreen`,
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
      const otherActivities = selectAllActivities(rootState);
      const otherActivityNames = otherActivities.map((a) => a.title || '');

      const group = selectAllGroups(rootState)[0];

      const { title: requestedTitle = 'New Screen', screenType = 'blank_screen' } = payload;

      const title = clearTitle(requestedTitle, otherActivityNames);
      const isHubSpokeScreen = screenType === QuestionTypeMapping.HUB_SPOKE;
      const activity: IActivityTemplate = {
        ...createActivityTemplate(),
        title,
        width: currentLesson.custom.defaultScreenWidth,
        height: currentLesson.custom.defaultScreenHeight,
      };
      activity.model.partsLayout = [await createSimpleText('Hello World')];

      activity.model.custom.maxAttempt = 3;

      const sourceScreenId = payload.fromScreenId;
      const flowchartData: AuthoringFlowchartScreenData = {
        paths: [],
        screenType,
        templateApplied: false,
      };
      activity.model.authoring.flowchart = flowchartData;

      if (payload.toScreenId) {
        flowchartData.paths.push(createAlwaysGoToPath(payload.toScreenId));
      } else {
        if (screenType === 'end_screen') {
          flowchartData.paths.push(createExitPath());
        } else if (sourceScreenId && !isHubSpokeScreen) {
          const sourceScreen = cloneT(selectActivityById(rootState, sourceScreenId));
          // if this new screen get added after the hub_spoke screen, we need to add the path to return to the source screen
          if (
            sourceScreen &&
            sourceScreen.authoring?.flowchart?.screenType === QuestionTypeMapping.HUB_SPOKE
          ) {
            flowchartData.paths.push(createAlwaysGoToPath(sourceScreenId));
          }
        } else {
          flowchartData.paths.push(createEndOfActivityPath());
        }
      }

      const createResults = await create(
        projectSlug,
        activity.typeSlug,
        activity.model,
        activity.objectives.attached,
      );

      if (createResults.result === 'failure') {
        throw new Error("Couldn't create activity: " + JSON.stringify(createResults));
      }

      const getLastScreenId = (): number | undefined => {
        const firstScreen = getFirstScreenInSequence(otherActivities, sequence);
        const orderedScreens = sortScreens(otherActivities, firstScreen).filter(
          (s) => s.authoring?.flowchart?.screenType !== 'end_screen',
        );
        if (orderedScreens.length === 0) {
          return undefined;
        }
        return orderedScreens[orderedScreens.length - 1].resourceId;
      };

      // If a from-screen isn't specified, then tack it on to the very end of the lesson.
      const fromScreenId = payload.fromScreenId || getLastScreenId();

      if (fromScreenId && !payload.skipPathToNewScreen) {
        // In this case, we need to edit that other screen's paths so it goes here.
        const fromScreen = cloneT(selectActivityById(rootState, fromScreenId));

        if (fromScreen) {
          if (payload.toScreenId) {
            // If we're adding a screen in the middle of a path, we need to update the destination of the "to" screen
            removeDestinationPath(fromScreen, payload.toScreenId);
          }

          if (hasDestinationPath(fromScreen)) {
            // If the "from" doesn't have any other paths, we can use an always-path, but if it does, we default
            // to an unknwon-path for the user to fill in later.
            setUnknownPathDestination(fromScreen, createResults.resourceId);
          } else {
            setGoToAlwaysPath(fromScreen, createResults.resourceId);
          }

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

      dispatch(saveActivity({ activity: reduxActivity, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: reduxActivity }));

      await dispatch(
        addSequenceItem({
          siblingId: getActivitySlugFromScreenResourceId(fromScreenId, sequence),
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
      dispatch(
        reportAPIError({
          error: JSON.stringify(e, Object.getOwnPropertyNames(e), 2),
          title: 'Could not add screen',
          message: 'A screen could not be added. Please try again.',
          failedActivity: null,
          info: null,
        }),
      );
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
