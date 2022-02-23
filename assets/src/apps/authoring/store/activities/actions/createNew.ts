import { createAsyncThunk } from '@reduxjs/toolkit';
import { create, Created } from 'data/persistence/activity';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import { selectState as selectPageState } from '../../../../authoring/store/page/slice';
import { selectActivityTypes, selectProjectSlug, selectReadOnly } from '../../app/slice';
import { createSimpleText } from '../templates/simpleText';
import { createCorrectRule, createIncorrectRule } from './rules';

export const createNew = createAsyncThunk(
  `${ActivitiesSlice}/createNew`,
  async (payload: any = {}, { dispatch, getState }) => {
    const rootState = getState() as any;
    const projectSlug = selectProjectSlug(rootState);
    // how to choose activity type? for now hard code to oli_adaptive?
    const activityTypes = selectActivityTypes(rootState);
    const currentLesson = selectPageState(rootState);

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

    // should populate with a template
    // TODO: type as creation model
    const activity: any = {
      type: 'activity',
      typeSlug: activityTypeSlug,
      title,
      objectives: { attached: [] }, // should populate with some from page?
      model: {
        authoring: {
          parts: [],
          rules: [],
        },
        custom: {
          applyBtnFlag: false,
          applyBtnLabel: '',
          checkButtonLabel: 'Next',
          combineFeedback: false,
          customCssClass: '',
          facts,
          lockCanvasSize: false,
          mainBtnLabel: '',
          maxAttempt: 0,
          maxScore: 0,
          negativeScoreAllowed: false,
          palette: {
            backgroundColor: 'rgba(255,255,255,0)',
            borderColor: 'rgba(255,255,255,0)',
            borderRadius: '',
            borderStyle: 'solid',
            borderWidth: '1px',
          },
          panelHeaderColor: 0,
          panelTitleColor: 0,
          showCheckBtn: true,
          trapStateScoreScheme: false,
          width: dimensions.width,
          height: dimensions.height,
          x: 0,
          y: 0,
          z: 0,
        },
        partsLayout: [await createSimpleText('Hello World')],
      },
    };

    /* activity.model.authoring.parts = activity.model.partsLayout.map((part: { id: string }) => ({
      id: part.id,
    })); */

    const { payload: defaultCorrect } = await dispatch(createCorrectRule({ isDefault: true }));

    const { payload: defaultIncorrect } = await dispatch(createIncorrectRule({ isDefault: true }));

    activity.model.authoring.rules.push(defaultCorrect, defaultIncorrect);

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
