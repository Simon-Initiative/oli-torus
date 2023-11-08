import React from 'react';
import { DDParticipationDefinition } from '../schema';

type Props = {
  requirements: DDParticipationDefinition;
};

export const DiscussionParticipation: React.FC<Props> = ({ requirements }) => {

  const { minPosts, maxPosts, minReplies, maxReplies, postDeadline, replyDeadline } = requirements;

  const hasParticipationRequirement =
    postDeadline || replyDeadline || minPosts > 0 || minReplies > 0;
  if (!hasParticipationRequirement) return null;
  return <div>Discussion Participation</div>;
};
