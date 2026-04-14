import { CheckResults } from '../store/features/adaptivity/slice';

type SupportedAdaptiveActionType = 'feedback' | 'mutateState' | 'navigation' | 'activationPoint';

type AdaptiveActionBuckets = Record<SupportedAdaptiveActionType, any[]>;

const createAdaptiveActionBuckets = (): AdaptiveActionBuckets => ({
  feedback: [],
  mutateState: [],
  navigation: [],
  activationPoint: [],
});

export const checkResultsHaveNavigation = (
  checkResults: CheckResults | undefined,
  currentActivityTree: any[] | undefined,
  currentActivityId: string | undefined,
) => {
  if (!currentActivityTree?.length) {
    return false;
  }

  const resultEvents = checkResults?.results;
  let eventsToProcess = Array.isArray(resultEvents) ? resultEvents : [];
  if (eventsToProcess.length === 0) {
    return false;
  }

  const actionsByType = createAdaptiveActionBuckets();
  const currentActivity = currentActivityTree[currentActivityTree.length - 1];
  const combineFeedback = !!currentActivity?.content?.custom?.combineFeedback;

  if (!combineFeedback) {
    eventsToProcess = [eventsToProcess[0]];
  }

  eventsToProcess.forEach((event: any) => {
    const actions = Array.isArray(event?.params?.actions) ? event.params.actions : [];

    actions.forEach((action: any) => {
      if (Object.prototype.hasOwnProperty.call(actionsByType, action?.type)) {
        actionsByType[action.type as keyof AdaptiveActionBuckets].push(action);
      }
    });
  });

  if (actionsByType.navigation.length === 0) {
    return false;
  }

  const [firstNavigationAction] = actionsByType.navigation;
  const target = firstNavigationAction?.params?.target;
  return typeof target === 'string' && target !== currentActivityId;
};
