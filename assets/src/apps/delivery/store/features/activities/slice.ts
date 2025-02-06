import {
  EntityAdapter,
  EntityId,
  EntityState,
  PayloadAction,
  Slice,
  createEntityAdapter,
  createSelector,
  createSlice,
} from '@reduxjs/toolkit';
import { ObjectiveMap } from 'data/content/activity';
import { AuthoringFlowchartScreenData } from '../../../../authoring/components/Flowchart/paths/path-types';
import ActivitiesSlice from './name';

interface IBasePartLayoutCustomProp {
  x: number;
  y: number;
  z: number;
  width: number;
  height: number;
  enabled?: boolean;
  requiresManualGrading?: boolean;
  [key: string]: any;
}

interface IBasePartLayout {
  id: string;
  type: string;
  custom: IBasePartLayoutCustomProp;
}

export enum AdvancedFeedbackAnswerType {
  Equal = 0,
  Between,
  Greater,
  GreatherEqual,
  Less,
  LessEqual,
}

export interface INumberAdvancedFeedback {
  answer?: {
    answerType: AdvancedFeedbackAnswerType;
    correctMax?: number;
    correctMin?: number;
    correctAnswer?: number;
  };
  feedback: string;
}

export interface INumericAnswer {
  range?: boolean;
  correctMax?: number;
  correctMin?: number;
  correctAnswer?: number;
}
export interface ISliderPartLayout extends IBasePartLayout {
  type: 'janus-slider';
  custom: {
    label: string;
    maximum: number;
    minimum: number;
    showLabel: boolean;
    showTicks: boolean;
    invertScale: boolean;
    showDataTip: boolean;
    snapInterval: number;
    customCssClass: string;
    showValueLabels: boolean;
    showThumbByDefault: boolean;

    answer?: INumericAnswer;
    correctFeedback?: string;
    incorrectFeedback?: string;
    advancedFeedback?: INumberAdvancedFeedback[];
  } & IBasePartLayoutCustomProp;
}

export interface IMultiLineTextPartLayout extends IBasePartLayout {
  type: 'janus-multi-line-text';
  custom: {
    label: string;
    prompt: string;
    fontSize: number;
    maxScore: number;
    showLabel: boolean;
    customCssClass: string;
    showCharacterCount: boolean;
    requiresManualGrading: false;
    minimumLength?: number;
    correctFeedback?: string;
    incorrectFeedback?: string;
  } & IBasePartLayoutCustomProp;
}
export interface IInputTextPartLayout extends IBasePartLayout {
  type: 'janus-input-text';
  custom: {
    label: string;
    prompt: string;
    showLabel: boolean;
    correctAnswer: {
      mustContain: string;
      minimumLength: number;
      mustNotContain: string;
    };
    customCssClass: string;
    maxManualGrade: number;
    correctFeedback: string;
    incorrectFeedback: string;
    showOnAnswersReport: boolean;
    requireManualGrading: boolean;
  } & IBasePartLayoutCustomProp;
}

export interface IInputNumberPartLayout extends IBasePartLayout {
  type: 'janus-inputNumber';
  custom: {
    label: string;
    answer?: INumericAnswer;
    prompt: string;
    maxScore: number;
    maxValue: number;
    minValue: number;
    showLabel: true;
    unitsLabel: string;
    maxManualGrade: number;
    correctFeedback?: string;
    advancedFeedback?: INumberAdvancedFeedback[];

    incorrectFeedback?: string;
    showIncrementArrows: boolean;
    requireManualGrading: boolean;
    requiresManualGrading: boolean;
  } & IBasePartLayoutCustomProp;
}

export interface IDropdownPartLayout extends IBasePartLayout {
  type: 'janus-dropdown';
  custom: {
    label: string;
    prompt: string;
    enabled: boolean;
    fontSize: number;
    maxScore: number;
    showLabel: boolean;
    optionLabels: string[];
    correctAnswer?: number;
    correctFeedback?: string;
    incorrectFeedback?: string;
    commonErrorFeedback?: string[];
    customCssClass: string;
  } & IBasePartLayoutCustomProp;
}

export interface IMCQPartLayout extends IBasePartLayout {
  type: 'janus-mcq';
  custom: {
    fontSize: number;
    maxScore: number;
    verticalGap: number;
    maxManualGrade: number;
    mcqItems: any[]; // TODO
    customCssClass: '';
    layoutType: 'verticalLayout' | 'horizontalLayout';
    enabled: boolean;
    randomize: boolean;
    showLabel: boolean;
    showNumbering: boolean;
    overrideHeight: boolean;
    multipleSelection: boolean;
    showOnAnswersReport: boolean;
    anyCorrectAnswer?: boolean;
    correctAnswer?: boolean[];
    correctFeedback?: string;
    incorrectFeedback?: string;
    commonErrorFeedback?: string[];
  } & IBasePartLayoutCustomProp;
}

export interface IHubSpokePartLayout extends IBasePartLayout {
  type: 'janus-hub-spoke';
  custom: {
    maxScore: number;
    verticalGap: number;
    spokeItems: any[];
    customCssClass: '';
    layoutType: 'verticalLayout' | 'horizontalLayout';
    enabled: boolean;
    showProgressBar: boolean;
    mustVisitAllSpokes: boolean;
    requiredSpoke: number;
    anyCorrectAnswer?: boolean;
    correctAnswer?: boolean[];
    correctFeedback?: string;
    spokeFeedback?: string;
    incorrectFeedback?: string;
    commonErrorFeedback?: string[];
  } & IBasePartLayoutCustomProp;
}

type KnownPartLayouts =
  | IMCQPartLayout
  | IDropdownPartLayout
  | IInputNumberPartLayout
  | ISliderPartLayout
  | IInputTextPartLayout
  | IMultiLineTextPartLayout;

interface OtherPartLayout extends IBasePartLayout {
  [key: string]: any;
}

export type IPartLayout = KnownPartLayouts | OtherPartLayout;

export interface ActivityContent {
  custom?: any;
  partsLayout: IPartLayout[];
  [key: string]: any;
}

export interface ICondition {
  fact: string; // ex: stage.dropdown.selectedItem,
  id: string; // ex: c:3723326255,
  operator: string; // ex: equal,
  type: number; // ex: 2,
  value: string; // ex: Correct
}

export interface IMutateAction {
  type: 'mutateState';
  params: {
    value: string;
    target: string;
    operator: string;
    targetType: number;
  };
}

export interface IFeedbackAction {
  type: 'feedback';
  id?: string;
  params: {
    id: string;
    feedback: {
      custom: any;
      partsLayout: IPartLayout[];
    };
  };
}

export interface INavigationAction {
  type: 'navigation';
  params: {
    target: string;
  };
}

export type IAction = IMutateAction | INavigationAction | IFeedbackAction; //| IScoreAction | IStageAction;

export interface IEvent {
  params: {
    actions: IAction[];
  };
  type: string;
}

export interface InitState {
  facts: any[];
}
export interface IAdaptiveRule {
  additionalScore?: number;
  conditions: {
    any?: ICondition[];
    all?: ICondition[];
    id?: string;
  };
  correct: boolean;
  default: boolean;
  disabled: boolean;
  event: IEvent;
  forceProgress?: boolean;
  id: string;
  name: string;
  priority: number;
}

export interface AuthoringParts {
  id: string; // ex: "janus_multi_line_text-1635445943",
  type: string; // ex: "janus-multi-line-text",
  owner: string; // ex: "adaptive_activity_5tcap_4078503139",
  inherited: boolean;
  gradingApproach?: 'manual' | 'automatic';
  outOf?: number;
}

export interface IActivity {
  id: EntityId;
  resourceId?: number;
  activitySlug?: string;
  authoring?: {
    rules?: IAdaptiveRule[];
    flowchart?: AuthoringFlowchartScreenData;
    parts?: AuthoringParts[];
    [key: string]: any;
  };
  content?: ActivityContent;
  activityType?: any;
  title?: string;
  objectives?: ObjectiveMap;
  tags?: number[];
  [key: string]: any;
}

export interface ActivitiesState extends EntityState<IActivity> {
  currentActivityId: EntityId;
}

const adapter: EntityAdapter<IActivity> = createEntityAdapter<IActivity>();

const slice: Slice<ActivitiesState> = createSlice({
  name: ActivitiesSlice,
  initialState: adapter.getInitialState({
    currentActivityId: '' as EntityId,
  }),
  reducers: {
    setActivities(state, action: PayloadAction<{ activities: IActivity[] }>) {
      adapter.setAll(state, action.payload.activities);
    },
    upsertActivity(state, action: PayloadAction<{ activity: IActivity }>) {
      adapter.upsertOne(state, action.payload.activity);
    },
    upsertActivities(state, action: PayloadAction<{ activities: IActivity[] }>) {
      adapter.upsertMany(state, action.payload.activities);
    },
    deleteActivity(state, action: PayloadAction<{ activityId: string }>) {
      adapter.removeOne(state, action.payload.activityId);
    },
    deleteActivities(state, action: PayloadAction<{ ids: string[] }>) {
      adapter.removeMany(state, action.payload.ids);
    },
    setCurrentActivityId(state, action: PayloadAction<{ activityId: EntityId }>) {
      state.currentActivityId = action.payload.activityId;
    },
  },
});

export const {
  setActivities,
  upsertActivity,
  upsertActivities,
  deleteActivity,
  deleteActivities,
  setCurrentActivityId,
} = slice.actions;

// SELECTORS
export const selectState = (state: { [ActivitiesSlice]: ActivitiesState }): ActivitiesState =>
  state[ActivitiesSlice] as ActivitiesState;

export const selectCurrentActivityId = createSelector(
  selectState,
  (state) => state.currentActivityId,
);
const { selectAll, selectById, selectTotal, selectEntities } = adapter.getSelectors(selectState);
export const selectAllActivities = selectAll;
export const selectActivityById = selectById;
export const selectTotalActivities = selectTotal;

export const selectCurrentActivity = createSelector(
  [selectEntities, selectCurrentActivityId],
  (activities, currentActivityId) => activities[currentActivityId],
);

export const selectCurrentActivityContent = createSelector(
  selectCurrentActivity,
  (activity) => activity?.content,
);

export default slice.reducer;
