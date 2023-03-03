import {
  createEntityAdapter,
  createSelector,
  createSlice,
  EntityAdapter,
  EntityId,
  EntityState,
  PayloadAction,
  Slice,
} from '@reduxjs/toolkit';
import { ObjectiveMap } from 'data/content/activity';
import { AuthoringFlowchartScreenData } from '../../../../authoring/components/Flowchart/paths/path-types';

import ActivitiesSlice from './name';

interface IBasePartLayout {
  id: string;
  type: string;
  custom: Record<string, any>;
}

export interface IMCQPartLayout extends IBasePartLayout {
  type: 'janus-mcq';
  custom: {
    x: number;
    y: number;
    z: number;
    width: number;
    height: number;
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
    requireManualGrading: boolean;
    requiresManualGrading: boolean;
  };
}

type KnownPartLayouts = IMCQPartLayout;

interface OtherPartLayout extends IBasePartLayout {
  [key: string]: any;
}

export type IPartLayout = KnownPartLayouts | OtherPartLayout;

export interface ActivityContent {
  custom?: any;
  partsLayout: IPartLayout[];
  [key: string]: any;
}

interface ICondition {
  fact: string; // ex: stage.dropdown.selectedItem,
  id: string; // ex: c:3723326255,
  operator: string; // ex: equal,
  type: number; // ex: 2,
  value: string; // ex: Correct
}

export interface IAction {
  params: {
    target: string;
  };
  type: string; // might be: "navigation" | "feedback" | "score" | "stage";
}

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
    id: string;
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

interface AuthoringParts {
  id: string; // ex: "janus_multi_line_text-1635445943",
  type: string; // ex: "janus-multi-line-text",
  owner: string; // ex: "adaptive_activity_5tcap_4078503139",
  inherited: boolean;
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
  tags: number[];
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
