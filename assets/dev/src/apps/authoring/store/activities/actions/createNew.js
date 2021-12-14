var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { createAsyncThunk } from '@reduxjs/toolkit';
import { create } from 'data/persistence/activity';
import { ActivitiesSlice } from '../../../../delivery/store/features/activities/slice';
import { selectState as selectPageState } from '../../../../authoring/store/page/slice';
import { selectActivityTypes, selectProjectSlug, selectReadOnly } from '../../app/slice';
import { createSimpleText } from '../templates/simpleText';
import { createCorrectRule, createIncorrectRule } from './rules';
export const createNew = createAsyncThunk(`${ActivitiesSlice}/createNew`, (payload = {}, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const rootState = getState();
    const projectSlug = selectProjectSlug(rootState);
    // how to choose activity type? for now hard code to oli_adaptive?
    const activityTypes = selectActivityTypes(rootState);
    const currentLesson = selectPageState(rootState);
    const isReadOnlyMode = selectReadOnly(rootState);
    const { activityTypeSlug = 'oli_adaptive', title = 'New Activity', dimensions = {
        width: currentLesson.custom.defaultScreenWidth,
        height: currentLesson.custom.defaultScreenHeight,
    }, facts = [], } = payload;
    // should populate with a template
    // TODO: type as creation model
    const activity = {
        type: 'activity',
        typeSlug: activityTypeSlug,
        title,
        objectives: { attached: [] },
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
            partsLayout: [yield createSimpleText('Hello World')],
        },
    };
    activity.model.authoring.parts = activity.model.partsLayout.map((part) => ({
        id: part.id,
    }));
    const { payload: defaultCorrect } = yield dispatch(createCorrectRule({ isDefault: true }));
    const { payload: defaultIncorrect } = yield dispatch(createIncorrectRule({ isDefault: true }));
    activity.model.authoring.rules.push(defaultCorrect, defaultIncorrect);
    let createResults = {
        resourceId: `readonly_${Date.now()}`,
        revisionSlug: `readonly_${Date.now()}`,
    };
    if (!isReadOnlyMode) {
        createResults = yield create(projectSlug, activityTypeSlug, activity.model, activity.objectives.attached);
    }
    // TODO: too many ways this property is defined!
    activity.activity_id = createResults.resourceId;
    activity.activityId = activity.activity_id;
    activity.resourceId = activity.activity_id;
    activity.activitySlug = createResults.revisionSlug;
    activity.activityType = activityTypes.find((type) => type.slug === activityTypeSlug);
    return activity;
}));
//# sourceMappingURL=createNew.js.map