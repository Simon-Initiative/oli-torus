import { createAsyncThunk } from '@reduxjs/toolkit';
import { setGroups } from '../../../../delivery/store/features/groups/slice';
import { PageContext } from '../../../types';
import { loadPage, PageSlice, PageState } from '../slice';

export const initializeFromContext = createAsyncThunk(
  `${PageSlice}/initializeFromContext`,
  async (params: PageContext, thunkApi) => {
    const { dispatch, getState } = thunkApi;

    // load the page state properties
    const pageState: PageState = {
      graded: params.graded,
      authorEmail: params.authorEmail,
      objectives: params.objectives,
      title: params.title,
    };
    dispatch(loadPage(pageState));

    // populate the group
    const groups = params.content.model.filter((item: any) => item.type === 'group');
    const otherTypes = params.content.model.filter((item: any) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
      groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }
    // wait for this to resolve so that state will be updated
    await dispatch(setGroups({ groups }));
    // populate the layout based on group

    // maybe do next in the group/layout specific code?
    // scan through and update all part references?
  },
);
