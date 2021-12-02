import { createAsyncThunk } from '@reduxjs/toolkit';
import { ResourceContent } from 'data/content/resource';
import { edit, Edited, ResourceUpdate } from 'data/persistence/resource';
import { clone } from 'utils/common';
import { selectAll as selectAllGroups } from '../../../../delivery/store/features/groups/slice';
import { selectProjectSlug, selectReadOnly } from '../../app/slice';
import { RootState } from '../../rootReducer';
import { PageSlice, PageState, selectRevisionSlug, selectState, setRevisionSlug } from '../slice';

export const savePage = createAsyncThunk(
  `${PageSlice}/savePage`,
  async (payload: Partial<PageState> = {}, { getState, dispatch }) => {
    const isReadOnlyMode = selectReadOnly(getState() as RootState);
    if (isReadOnlyMode) {
      return;
    }
    const projectSlug = selectProjectSlug(getState() as RootState);
    const revisionSlug = selectRevisionSlug(getState() as RootState);
    const currentPage = selectState(getState() as RootState);

    const model = selectAllGroups(getState() as any);

    const advancedAuthoring =
      payload.advancedAuthoring !== undefined
        ? payload.advancedAuthoring
        : currentPage.advancedAuthoring;
    const advancedDelivery =
      payload.advancedDelivery !== undefined
        ? payload.advancedDelivery
        : currentPage.advancedDelivery;
    const displayApplicationChrome =
      payload.displayApplicationChrome !== undefined
        ? payload.displayApplicationChrome
        : currentPage.displayApplicationChrome;

    // the API expects to overwrite all the properties every time

    // need to strip out resourceId from the model items and their children
    // we don't want to persist that value
    const updatedModel = clone(model);
    const removeResourceId = (items: any[]) => {
      items.forEach((item) => {
        delete item.resourceId;
        if (item.children) {
          removeResourceId(item.children);
        }
      });
    };
    removeResourceId(updatedModel);

    const update: ResourceUpdate = {
      title: payload.title || currentPage.title,
      objectives: payload.objectives || currentPage.objectives,
      content: {
        model: updatedModel as ResourceContent[],
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

    const saveResult = await edit(projectSlug, revisionSlug, update, false);

    if (saveResult.type === 'ServerError') {
      throw new Error(saveResult.message);
    }

    const newSlug = (saveResult as Edited).revision_slug;
    if (newSlug !== revisionSlug) {
      /* console.log('updating slug??', { saveResult, newSlug, revisionSlug }); */
      dispatch(setRevisionSlug({ revisionSlug: newSlug }));
    }
  },
);
