import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  defaultGlobalEnv,
  evalScript,
  getAssignStatements,
  getValue,
  setVariableWithTypeAssignStatements,
} from '../../../../../../adaptivity/scripting';
import { deferredSavePart } from '../../../../../../data/persistence/deferredSavePart';
import { DeliveryRootState } from '../../../rootReducer';
import { selectPreviewMode, selectSectionSlug } from '../../page/slice';
import AttemptSlice from '../name';
import { selectActivityAttemptState, selectById, upsertActivityAttemptState } from '../slice';

interface SavePartPayload {
  attemptGuid: string;
  partAttemptGuid: string;
  response: any;
}

export const savePartState = createAsyncThunk(
  `${AttemptSlice}/savePartState`,
  async (payload: SavePartPayload, { dispatch, getState }) => {
    const { attemptGuid, partAttemptGuid, response } = payload;
    const rootState = getState() as DeliveryRootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const attemptNumber = getValue('session.attemptNumber', defaultGlobalEnv);

    let updatedPartResponses = response;
    // update redux state to match optimistically
    const attemptRecord = selectById(rootState, attemptGuid);
    if (attemptRecord) {
      const partAttemptRecord = attemptRecord.parts.find((p) => p.attemptGuid === partAttemptGuid);
      if (partAttemptRecord) {
        const updated = {
          ...attemptRecord,
          attemptNumber: attemptNumber,
          parts: attemptRecord.parts.map((p) => {
            const result = { ...p };
            if (p.attemptGuid === partAttemptRecord.attemptGuid) {
              // always want to merge the previous response inputs into the attempt
              // overwrite with later info, but don't delete
              updatedPartResponses = {
                ...result.response,
                ...updatedPartResponses,
              };
              if (isPreviewMode) {
                updatedPartResponses = {
                  ...updatedPartResponses,
                  partId: p.partId,
                };
              }
              result.response = updatedPartResponses;
            }
            return result;
          }),
        };
        await dispatch(upsertActivityAttemptState({ attempt: updated }));
      }
    }
    if (isPreviewMode && updatedPartResponses?.partId?.length) {
      setVariableWithTypeAssignStatements(updatedPartResponses, updatedPartResponses?.partId);
    }
    // update scripting env with latest value
    const assignScripts = getAssignStatements(updatedPartResponses);
    const scriptResult: string[] = [];
    if (Array.isArray(assignScripts)) {
      //Need to execute scripts one-by-one so that error free expression are evaluated and only the expression with error fails. It should not have any impacts
      assignScripts.forEach((variable: string) => {
        // update scripting env with latest values
        const { result } = evalScript(variable, defaultGlobalEnv);
        //Usually, the result is always null if expression is executes successfully. If there are any errors only then the result contains the error message
        if (result) scriptResult.push(result);
      });
    }
    /*  console.log('SAVE PART SCRIPT', { assignScript, scriptResult }); */

    // in preview mode we don't write to server, so we're done
    if (isPreviewMode) {
      // TODO: normalize response between client and server (nothing currently cares about it)
      return { result: scriptResult };
    }

    const finalize = false;

    deferredSavePart(sectionSlug, attemptGuid, partAttemptGuid, updatedPartResponses, finalize);

    // writePartAttemptState(
    //   sectionSlug,
    //   attemptGuid,
    //   partAttemptGuid,
    //   updatedPartResponses,
    //   finalize,
    // );
  },
);

export const savePartStateToTree = createAsyncThunk(
  `${AttemptSlice}/savePartStateToTree`,
  async (payload: any, { dispatch, getState }) => {
    const { attemptGuid, partAttemptGuid, response, activityTree } = payload;
    const rootState = getState() as DeliveryRootState;

    const attemptRecord = selectById(rootState, attemptGuid);
    const partId = attemptRecord?.parts.find((p) => p.attemptGuid === partAttemptGuid)?.partId;
    if (!partId) {
      throw new Error('cannot find the partId to update');
    }

    const updates = activityTree.map((activity: any) => {
      const attempt = selectActivityAttemptState(rootState, activity.resourceId);
      if (!attempt) {
        return Promise.reject('could not find attempt!');
      }
      const attemptGuid = attempt.attemptGuid;
      const partAttemptGuid = attempt.parts.find((p) => p.partId === partId)?.attemptGuid;
      if (!partAttemptGuid) {
        // means its in the tree, but doesn't own or inherit this part (some grandparent likely)
        return Promise.resolve('does not own part but thats OK');
      }
      /* console.log('updating activity tree part: ', {
        attemptGuid,
        partAttemptGuid,
        activity,
        response,
      }); */
      return dispatch(savePartState({ attemptGuid, partAttemptGuid, response }));
    });
    return Promise.all(updates);
  },
);
