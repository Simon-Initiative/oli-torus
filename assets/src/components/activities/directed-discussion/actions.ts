import { DDParticipationDefinition, DirectedDiscussionActivitySchema } from './schema';

export const DirectedDiscussionActions = {
  editParticipation:
    (participation: DDParticipationDefinition) => (model: DirectedDiscussionActivitySchema) => {
      model.participation = participation;
    },
};
