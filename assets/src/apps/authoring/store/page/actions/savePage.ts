import { createAsyncThunk } from '@reduxjs/toolkit';
import { ResourceContent } from 'data/content/resource';
import { edit, Edited, ResourceUpdate } from 'data/persistence/resource';
import { selectAll as selectAllGroups } from '../../../../delivery/store/features/groups/slice';
import { acquireEditingLock, releaseEditingLock } from '../../app/actions/locking';
import { selectProjectSlug } from '../../app/slice';
import { RootState } from '../../rootReducer';
import { PageSlice, PageState, selectRevisionSlug, selectState, setRevisionSlug } from '../slice';

export const savePage = createAsyncThunk(
  `${PageSlice}/savePage`,
  async (payload: Partial<PageState> = {}, { getState, dispatch }) => {
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
    const update: ResourceUpdate = {
      title: payload.title || currentPage.title,
      objectives: payload.objectives || currentPage.objectives,
      content: {
        model: (model as ResourceContent[]),
        advancedAuthoring,
        advancedDelivery,
        displayApplicationChrome,
        custom: payload.custom || currentPage.custom,
        customCss: payload.customCss || currentPage.customCss,
        additionalStylesheets: payload.additionalStylesheets || currentPage.additionalStylesheets,
      },
      releaseLock: false,
    };

    await dispatch(acquireEditingLock());

    const saveResult = await edit(projectSlug, revisionSlug, update, false);

    await dispatch(releaseEditingLock());

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
