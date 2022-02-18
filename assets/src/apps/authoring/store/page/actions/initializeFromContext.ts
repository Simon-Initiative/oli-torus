import { createAsyncThunk } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import {
  setActivities,
  setCurrentActivityId,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { setGroups } from '../../../../delivery/store/features/groups/slice';
import { PageContext } from '../../../types';
import { createNew as createNewActivity } from '../../activities/actions/createNew';
import { createNew as createNewGroup } from '../../groups/layouts/deck/actions/createNew';
import { updateActivityPartInheritance } from '../../groups/layouts/deck/actions/updateActivityPartInheritance';
import { updateActivityRules } from '../../groups/layouts/deck/actions/updateActivityRules';
import { loadPage, PageState } from '../slice';
import PageSlice from '../name';
import { savePage } from './savePage';

export const initializeFromContext = createAsyncThunk(
  `${PageSlice}/initializeFromContext`,
  async (params: { context: PageContext; config: any }, thunkApi) => {
    const { dispatch, getState } = thunkApi;

    // load the page state properties
    const pageState: Partial<PageState> = {
      graded: params.context.graded,
      authorEmail: params.context.authorEmail,
      objectives: params.context.objectives,
      title: params.context.title,
      revisionSlug: params.context.resourceSlug,
      resourceId: params.context.resourceId,
      additionalStylesheets: params.context.content.additionalStylesheets,
      customCss: params.context.content.customCss,
      customScript: params.context.content.customScript,
      custom: params.context.content.custom || {},
    };
    if (!params.context.content.model.length && !pageState.custom.themeId) {
      pageState.custom.themeId = 'torus-default-light';
      pageState.additionalStylesheets = ['/css/delivery_adaptive_themes_default_light.css'];
    }
    if (pageState.custom.maxScore === undefined) {
      pageState.custom.maxScore = pageState.custom.totalScore;
    }
    dispatch(loadPage(pageState));

    const children: any[] = Object.keys(params.context.activities).map((id) => ({
      ...params.context.activities[id],
    }));
    let pageModel = params.context.content.model;
    if (!pageModel.length) {
      // this should be a "new" lesson, at no point should we allow the model
      // to be empty while controlled by the authoring tool
      // if there are any activities defined that are not in a group they will be
      // assimilated into a new group
      if (!children.length) {
        const { payload: newActivity } = await dispatch(createNewActivity({}));
        children.push(newActivity);
      }
      // create sequence map of activities which is the group children
      const newSequence = children.map((childActivity) => {
        const entry = {
          type: 'activity-reference',
          resourceId: childActivity.activityId,
          activitySlug: childActivity.activitySlug,
          custom: {
            sequenceId: `aa_${guid()}`,
            sequenceName: childActivity.title || childActivity.activitySlug,
          },
        };
        return entry;
      });
      const { payload: newGroup } = await dispatch(createNewGroup({ children: newSequence }));

      // write model to server now or else the above created activity will be orphaned
      await dispatch(savePage({ undoable: true }));

      pageModel = [newGroup];
    }

    const activityTypes = params.config.activityTypes;

    // set the activities
    const activities = children.map((activity) => {
      return {
        id: activity.activity_id,
        resourceId: activity.activity_id,
        activitySlug: activity.activitySlug,
        activityType: activityTypes.find((at: any) => at.slug === activity.typeSlug),
        content: { ...activity.model, authoring: undefined },
        authoring: activity.model.authoring,
        title: activity.title,
        objectives: activity.objectives,
      };
    });
    await dispatch(setActivities({ activities }));

    // populate the group
    // TODO: can this be recursively nested?
    const groups = pageModel.filter((item: any) => item.type === 'group');
    const otherTypes = pageModel.filter((item: any) => item.type !== 'group');
    // for now just stick them into a group, this isn't reallly thought out yet
    // and there is technically only 1 supported layout type atm
    if (otherTypes.length) {
      groups.push({ type: 'group', layout: 'deck', children: [...otherTypes] });
    }

    // need resourceId in the group to be able to match it with the activity
    groups.forEach((group) => {
      group.children.forEach((child: any) => {
        if (child.type === 'activity-reference' && !child.resourceId) {
          const matchingActivity = activities.find(
            (activity) => activity.activitySlug === child.activitySlug,
          );
          if (matchingActivity) {
            child.resourceId = matchingActivity.resourceId;
          }
        }
      });
    });

    // here we should do any "layout processing" where for example we go and make sure all the parts
    // are referenced including inherited from layers or parent screens when in "deck" view
    // afterwards update that group record with a processing timestamp? so that we don't need to do every time?
    // NOTE: right now there really only is expected to be a single group
    const groupProcessing = groups.map((group) => dispatch(updateActivityPartInheritance(group)));
    const ruleProcessing = groups.map((group) => dispatch(updateActivityRules(group)));

    // TODO: different for different layout types
    await Promise.all(groupProcessing);
    await Promise.all(ruleProcessing);

    await dispatch(setGroups({ groups }));

    console.log('INIT:', { params, children, groups, activities });

    // TODO: some initial creation if blank
    const sequence = selectSequence(getState() as any);
    await dispatch(setCurrentActivityId({ activityId: sequence[0]?.resourceId }));
  },
);
