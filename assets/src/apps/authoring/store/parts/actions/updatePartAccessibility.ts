import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectActivityById } from 'apps/delivery/store/features/activities/slice';
import { clone } from 'utils/common';
import { saveActivity } from '../../activities/actions/saveActivity';
import { PartsSlice } from '../name';

export const findPartInActivity = (
  activity: any,
  partId: string,
  parentPopupId?: string,
): any | null => {
  const partsLayout = activity?.content?.partsLayout || [];

  if (parentPopupId) {
    const popupPart = partsLayout.find((part: any) => part.id === parentPopupId);
    const nestedParts = popupPart?.custom?.popup?.partsLayout || [];
    return nestedParts.find((part: any) => part.id === partId) ?? null;
  }

  return partsLayout.find((part: any) => part.id === partId) ?? null;
};

export const setNestedCustomValue = (
  part: any,
  fieldPath: string,
  value: string | boolean,
): void => {
  if (!part.custom) {
    part.custom = {};
  }

  const parts = fieldPath.split('.');
  let current = part.custom;

  for (let i = 0; i < parts.length - 1; i++) {
    const key = parts[i];
    if (!current[key] || typeof current[key] !== 'object') {
      current[key] = {};
    }
    current = current[key];
  }

  current[parts[parts.length - 1]] = value;
};

export const updatePartAccessibilityField = createAsyncThunk(
  `${PartsSlice}/updatePartAccessibilityField`,
  async (
    payload: {
      activityId: string;
      partId: string;
      parentPopupId?: string;
      fieldPath: string;
      value: string | boolean;
    },
    { getState, dispatch },
  ) => {
    const rootState = getState() as any;
    const activity = selectActivityById(rootState, payload.activityId);

    if (!activity) {
      throw new Error(`Activity: ${payload.activityId} not found!`);
    }

    const activityClone = clone(activity);
    const part = findPartInActivity(activityClone, payload.partId, payload.parentPopupId);

    if (!part) {
      throw new Error(
        `Part: ${payload.partId} not found in Activity: ${payload.activityId}${
          payload.parentPopupId ? ` (popup: ${payload.parentPopupId})` : ''
        }`,
      );
    }

    setNestedCustomValue(part, payload.fieldPath, payload.value);

    await dispatch(
      saveActivity({
        activity: activityClone,
        undoable: true,
        immediate: true,
      }),
    );

    return { activity: activityClone };
  },
);
