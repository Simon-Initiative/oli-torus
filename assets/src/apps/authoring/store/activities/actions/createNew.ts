import { selectState as selectPageState } from '../../../../authoring/store/page/slice';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import { createEndOfActivityPath } from '../../../components/Flowchart/paths/path-factories';
import { AuthoringFlowchartScreenData } from '../../../components/Flowchart/paths/path-types';
import {
  selectActivityTypes,
  selectAppMode,
  selectProjectSlug,
  selectReadOnly,
} from '../../app/slice';
import { createActivityTemplate } from '../templates/activity';
import { createSimpleText } from '../templates/simpleText';
import { createCorrectRule, createIncorrectRule } from './rules';
import { createAsyncThunk } from '@reduxjs/toolkit';
import { Created, create } from 'data/persistence/activity';
import merge from 'lodash/merge';

interface CreateNewPayload {
  activityTypeSlug?: string;
  title?: string;
  dimensions?: {
    width?: number;
    height?: number;
  };
  facts?: any[];
  screenType?: string;
}

export const createNew = createAsyncThunk(
  `${ActivitiesSlice}/createNew`,
  async (payload: CreateNewPayload = {}, { dispatch, getState }) => {
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    // how to choose activity type? for now hard code to oli_adaptive?
    const activityTypes = selectActivityTypes(rootState);
    const currentLesson = selectPageState(rootState);
    const appMode = selectAppMode(rootState);

    const isReadOnlyMode = selectReadOnly(rootState);

    const {
      activityTypeSlug = 'oli_adaptive',
      title = 'New Activity',
      dimensions = {
        width: currentLesson.custom.defaultScreenWidth,
        height: currentLesson.custom.defaultScreenHeight,
      },
      facts = [],
    } = payload;

    // TODO: type as creation model
    const activity: any = merge(createActivityTemplate(), {
      typeSlug: activityTypeSlug,
      title,
      model: {
        custom: {
          facts,
          width: dimensions.width,
          height: dimensions.height,
        },
        partsLayout: [await createSimpleText('Hello World')],
      },
    });

    if (appMode === 'flowchart') {
      const flowchartData: AuthoringFlowchartScreenData = {
        paths: [createEndOfActivityPath()],
        screenType: payload.screenType || 'blank_screen',
        templateApplied: false,
      };
      activity.model.authoring.flowchart = flowchartData;
    } else {
      const { payload: defaultCorrect } = await dispatch(createCorrectRule({ isDefault: true }));
      const { payload: defaultIncorrect } = await dispatch(
        createIncorrectRule({ isDefault: true }),
      );
      activity.model.authoring.rules.push(defaultCorrect, defaultIncorrect);
    }

    let createResults: any = {
      resourceId: `readonly_${Date.now()}`,
      revisionSlug: `readonly_${Date.now()}`,
    };

    if (!isReadOnlyMode) {
      createResults = await create(
        projectSlug,
        activityTypeSlug,
        activity.model,
        activity.objectives.attached,
      );
    }

    // TODO: too many ways this property is defined!
    activity.activity_id = (createResults as Created).resourceId;
    activity.activityId = activity.activity_id;
    activity.resourceId = activity.activity_id;
    activity.activitySlug = (createResults as Created).revisionSlug;

    activity.activityType = activityTypes.find((type: any) => type.slug === activityTypeSlug);

    return activity;
  },
);
