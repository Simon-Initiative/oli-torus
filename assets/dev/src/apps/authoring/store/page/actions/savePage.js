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
import { edit } from 'data/persistence/resource';
import { clone } from 'utils/common';
import { selectAll as selectAllGroups } from '../../../../delivery/store/features/groups/slice';
import { selectProjectSlug, selectReadOnly } from '../../app/slice';
import { PageSlice, selectRevisionSlug, selectState, setRevisionSlug } from '../slice';
export const savePage = createAsyncThunk(`${PageSlice}/savePage`, (payload = {}, { getState, dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    const isReadOnlyMode = selectReadOnly(getState());
    if (isReadOnlyMode) {
        return;
    }
    const projectSlug = selectProjectSlug(getState());
    const revisionSlug = selectRevisionSlug(getState());
    const currentPage = selectState(getState());
    const model = selectAllGroups(getState());
    const advancedAuthoring = payload.advancedAuthoring !== undefined
        ? payload.advancedAuthoring
        : currentPage.advancedAuthoring;
    const advancedDelivery = payload.advancedDelivery !== undefined
        ? payload.advancedDelivery
        : currentPage.advancedDelivery;
    const displayApplicationChrome = payload.displayApplicationChrome !== undefined
        ? payload.displayApplicationChrome
        : currentPage.displayApplicationChrome;
    // the API expects to overwrite all the properties every time
    // need to strip out resourceId from the model items and their children
    // we don't want to persist that value
    const updatedModel = clone(model);
    const removeResourceId = (items) => {
        items.forEach((item) => {
            delete item.resourceId;
            if (item.children) {
                removeResourceId(item.children);
            }
        });
    };
    removeResourceId(updatedModel);
    const update = {
        title: payload.title || currentPage.title,
        objectives: payload.objectives || currentPage.objectives,
        content: {
            model: updatedModel,
            advancedAuthoring,
            advancedDelivery,
            displayApplicationChrome,
            custom: payload.custom || currentPage.custom,
            customCss: payload.customCss || currentPage.customCss,
            customScript: payload.customScript || currentPage.customScript,
            additionalStylesheets: payload.additionalStylesheets || currentPage.additionalStylesheets,
        },
        releaseLock: false,
    };
    const saveResult = yield edit(projectSlug, revisionSlug, update, false);
    if (saveResult.type === 'ServerError') {
        throw new Error(saveResult.message);
    }
    const newSlug = saveResult.revision_slug;
    if (newSlug !== revisionSlug) {
        /* console.log('updating slug??', { saveResult, newSlug, revisionSlug }); */
        dispatch(setRevisionSlug({ revisionSlug: newSlug }));
    }
}));
//# sourceMappingURL=savePage.js.map