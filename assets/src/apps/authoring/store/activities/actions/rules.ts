import { createAsyncThunk } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import { createFeedback } from './createFeedback';
import {
  AdaptiveRule,
  InitState,
} from 'apps/authoring/components/AdaptiveRulesList/AdaptiveRulesList';
import isArray from 'lodash/isArray';
import isObject from 'lodash/isObject';
import set from 'lodash/set';
import cloneDeep from 'lodash/cloneDeep';
import reduce from 'lodash/reduce';
import has from 'lodash/has';

const newId = (val: { [key: string]: any }) => {
  const idx = val?.indexOf(':');
  return `${val?.substring(0, idx)}:${guid()}`;
};

function replace(source: any, key: string): any {
  return isArray(source)
    ? source.map((v: any) => replace(v, key))
    : isObject(source)
    ? reduce(
        has(source, key) ? set(source, key, newId(source[key as keyof typeof source])) : source,
        (res: any, v: any, i: string | number) => {
          res[i] = replace(v, key);
          return res;
        },
        {},
      )
    : source;
}

export const duplicateRule = createAsyncThunk(
  `${ActivitiesSlice}/duplicateRule`,
  async (payload: AdaptiveRule | InitState) => {
    const clone = cloneDeep(payload);
    const replaced = replace(clone, 'id');
    // console.log(replaced, payload);
    return replaced;
  },
);

export const createCorrectRule = createAsyncThunk(
  `${ActivitiesSlice}/createCorrectRule`,
  async (payload: { ruleId?: string; isDefault?: boolean }) => {
    const { ruleId = `r:${guid()}`, isDefault = false } = payload;

    const rule = {
      id: `${ruleId}.correct`,
      name: 'correct',
      disabled: false,
      additionalScore: 0.0,
      forceProgress: false,
      default: isDefault,
      correct: true,
      conditions: { all: [] },
      event: {
        type: `${ruleId}.correct`,
        params: {
          actions: [
            {
              type: 'navigation',
              params: { target: 'next' },
            },
          ],
        },
      },
    };

    return rule;
  },
);

export const createIncorrectRule = createAsyncThunk(
  `${ActivitiesSlice}/createIncorrectRule`,
  async (payload: { ruleId?: string; isDefault?: boolean }, { dispatch }) => {
    const { ruleId = `r:${guid()}`, isDefault = false } = payload;

    const { payload: feedbackAction } = await dispatch(createFeedback({}));

    const name = isDefault ? 'defaultWrong' : 'incorrect';

    const rule = {
      id: `${ruleId}.${name}`,
      name,
      disabled: false,
      additionalScore: 0.0,
      forceProgress: false,
      default: isDefault,
      correct: false,
      conditions: { all: [] },
      event: {
        type: `${ruleId}.${name}`,
        params: {
          actions: [feedbackAction],
        },
      },
    };

    return rule;
  },
);
