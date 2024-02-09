import { DDParticipationDefinition, DirectedDiscussionActivitySchema } from './schema';

// Returns value 0 or more
const minZero = (value: number) => Math.max(0, value);

// If max is 0 or less, returns 0  (ie: there is no max value)
// If max is less than min, returns min  (ie. Max is never lower than min)
// Otherwise returns max
const minMax = (min: number, max: number) => minZero(max === 0 ? 0 : Math.max(min, max));

export const DirectedDiscussionActions = {
  editParticipation:
    (participation: DDParticipationDefinition) => (model: DirectedDiscussionActivitySchema) => {
      model.participation = {
        minPosts: minZero(participation.minPosts),
        minReplies: minZero(participation.minReplies),
        maxWordLength: minZero(participation.maxWordLength),
        maxPosts: minMax(participation.minPosts, participation.maxPosts),
        maxReplies: minMax(participation.minReplies, participation.maxReplies),
      };
    },
};
