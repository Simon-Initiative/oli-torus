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
import guid from 'utils/guid';
import { ActivitiesSlice } from '../../../../delivery/store/features/activities/slice';
import { createFeedback } from './createFeedback';
export const createCorrectRule = createAsyncThunk(`${ActivitiesSlice}/createCorrectRule`, (payload) => __awaiter(void 0, void 0, void 0, function* () {
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
}));
export const createIncorrectRule = createAsyncThunk(`${ActivitiesSlice}/createIncorrectRule`, (payload, { dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    const { ruleId = `r:${guid()}`, isDefault = false } = payload;
    const { payload: feedbackAction } = yield dispatch(createFeedback({}));
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
}));
//# sourceMappingURL=rules.js.map