import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { ResourceContent } from 'data/content/resource';
import { edit, Edited, ResourceUpdate } from 'data/persistence/resource';
import { clone } from 'utils/common';
import cloneDeep from 'lodash/cloneDeep';
import { selectAll as selectAllGroups } from '../../../../delivery/store/features/groups/slice';
import { selectAppMode, selectProjectSlug, selectReadOnly } from '../../app/slice';
import { AuthoringRootState } from '../../rootReducer';
import { PageState, selectRevisionSlug, selectState, setRevisionSlug, updatePage } from '../slice';
import PageSlice from '../name';
import { createUndoAction } from '../../history/slice';
import { debounce } from 'lodash';
import { SAVE_DEBOUNCE_OPTIONS, SAVE_DEBOUNCE_TIMEOUT } from '../../persistance-options';

export interface PagePayload extends Partial<PageState> {
  undoable?: boolean;
  immiediate?: boolean; // Do not debounce the save.
}

export const savePage = createAsyncThunk(
  `${PageSlice}/savePage`,
  async (payload: PagePayload, { getState, dispatch }) => {
    const { undoable = false } = payload;

    const isReadOnlyMode = selectReadOnly(getState() as AuthoringRootState);
    if (isReadOnlyMode) {
      return;
    }
    const projectSlug = selectProjectSlug(getState() as AuthoringRootState);
    const revisionSlug = selectRevisionSlug(getState() as AuthoringRootState);
    const currentPage = selectState(getState() as AuthoringRootState);

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

    // need to update totalScore
    const customUpdate = clone(payload.custom || currentPage.custom);

    if (!customUpdate.scoreFixed) {
      // need to calculate totalScore by all activities
      const sequence = selectSequence(getState() as any);
      const allActivities = selectAllActivities(getState() as any);
      const totalScore = sequence.reduce((acc, sequenceItem) => {
        if (sequenceItem.custom.isLayer || sequenceItem.custom.isBank) {
          return acc;
        }
        const currActivity: any = allActivities.find((a) => a.id === sequenceItem.resourceId);
        if (!currActivity) {
          return acc;
        }
        return acc + (currActivity?.content?.custom?.maxScore || 0);
      }, 0);
      customUpdate.totalScore = totalScore;
    }

    const update: ResourceUpdate = {
      title: payload.title || currentPage.title,
      objectives: payload.objectives || currentPage.objectives,
      content: {
        model: updatedModel as ResourceContent[],
        advancedAuthoring,
        advancedDelivery,
        displayApplicationChrome,
        custom: customUpdate,
        customCss: payload.customCss ?? currentPage.customCss,
        customScript: payload.customScript ?? currentPage.customScript,
        additionalStylesheets: payload.additionalStylesheets ?? currentPage.additionalStylesheets,
      },
      releaseLock: false,
    };

    dispatch(updatePage(update.content));

    if (undoable) {
      dispatch(
        createUndoAction({
          undo: [savePage(cloneDeep({ ...currentPage, undoable: false }))],
          redo: [savePage(cloneDeep({ ...payload, undoable: false }))],
        }),
      );
    }

    _edit(projectSlug, revisionSlug, update, dispatch);
    if (payload.immiediate) {
      await _edit.flush();
    }
  },
);

const _edit = debounce(
  async (
    projectSlug: string,
    revisionSlug: string,
    update: any,
    dispatch: (action: any) => void,
  ) => {
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
  SAVE_DEBOUNCE_TIMEOUT,
  SAVE_DEBOUNCE_OPTIONS,
);
