import React from 'react';
import { Icon } from 'components/misc/Icon';
import { DDParticipationDefinition } from '../schema';
import { CurrentParticipation } from './participation-util';

type Props = {
  requirements: DDParticipationDefinition;
  participation: CurrentParticipation;
  currentUserId: number;
};

export const DiscussionParticipation: React.FC<Props> = ({
  currentUserId,
  requirements,
  participation,
}) => {
  const { minPosts, maxPosts, minReplies, maxReplies } = requirements;

  const showMinPosts = minPosts > 0;
  const showMaxPosts = maxPosts > 0;
  const showMinReplies = minReplies > 0;
  const showMaxReplies = maxReplies > 0;

  const hasParticipationRequirement = minPosts > 0 || minReplies > 0;

  if (!hasParticipationRequirement) return null;

  return (
    <div>
      {showMinPosts && (
        <ParticipationState
          target={minPosts}
          current={participation.posts}
          status={participation.posts >= minPosts ? 'complete' : 'incomplete'}
        >
          Minimum Posts
        </ParticipationState>
      )}
      {showMaxPosts && (
        <ParticipationState target={maxPosts} current={participation.posts} status="">
          Maximum Posts
        </ParticipationState>
      )}
      {showMinReplies && (
        <ParticipationState
          target={minReplies}
          current={participation.replies}
          status={participation.replies >= minReplies ? 'complete' : 'incomplete'}
        >
          Minimum Replies
        </ParticipationState>
      )}
      {showMaxReplies && (
        <ParticipationState target={maxReplies} current={participation.replies} status="">
          Maximum Replies
        </ParticipationState>
      )}
    </div>
  );
};

const ParticipationState: React.FC<{
  target: number;
  current: number;
  status: 'complete' | 'incomplete' | '';
  children: React.ReactNode;
}> = ({ children, target, current, status }) => {
  const icon =
    status === 'complete' ? (
      <Icon icon="check" className="text-green-600" />
    ) : status === 'incomplete' ? (
      <Icon className="text-red-700" icon="times" />
    ) : (
      ''
    );
  return (
    <label className="bg-gray-400 rounded-md px-2 m-2 text-sm">
      {children} {current}/{target} {icon}
    </label>
  );
};
