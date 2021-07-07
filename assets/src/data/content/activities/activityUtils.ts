import { ActivityState } from 'components/activities/types';

export const isCorrect = (activityState: ActivityState) => activityState.score !== 0;
