import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  setActivities,
  setCurrentActivityId,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { setGroups } from '../../../../delivery/store/features/groups/slice';
import { PageContext } from '../../../types';
import { updateActivityPartInheritance } from '../../groups/layouts/deck/actions/updateActivityPartInheritance';
import { loadPage, PageSlice, PageState } from '../slice';

export const initializeFromContext = createAsyncThunk(
  `${PageSlice}/initializeFromContext`,
  async (params: PageContext, thunkApi) => {
    const { dispatch, getState } = thunkApi;

    // load the page state properties
    const pageState: Partial<PageState> = {
      graded: params.graded,
      authorEmail: params.authorEmail,
      objectives: params.objectives,
      title: params.title,
      revisionSlug: params.resourceSlug,
      resourceId: params.resourceId,
    };
    dispatch(loadPage(pageState));

    // load activities
    const activities = Object.keys(params.activities).map((id) => {
      return { ...params.activities[id], id };
    });
    await dispatch(setActivities({ activities }));

    // populate the group
    // TODO: can this be recursively nested?
    const groups = params.content.model.filter((item: any) => item.type === 'group');
    const otherTypes = params.content.model.filter((item: any) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
      groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }
    // here we should do any "layout processing" where for example we go and make sure all the parts
    // are referenced including inherited from layers or parent screens when in "deck" view
    // afterwards update that group record with a processing timestamp? so that we don't need to do every time?
    // NOTE: right now there really only is expected to be a single group
    const groupProcessing = groups.map((group) => dispatch(updateActivityPartInheritance(group)));
    // TODO: different for different layout types
    await Promise.all(groupProcessing);

    await dispatch(setGroups({ groups }));

    // TODO: some initial creation if blank
    const sequence = selectSequence(getState() as any);
    await dispatch(setCurrentActivityId({ activityId: sequence[0]?.activitySlug }));
  },
);
