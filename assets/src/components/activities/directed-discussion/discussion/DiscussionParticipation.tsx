import React from 'react';
import { DDParticipationDefinition } from '../schema';
import { CurrentParticipation } from './participation-util';

type Props = {
  requirements: DDParticipationDefinition;
  participation: CurrentParticipation;
};

export const DiscussionParticipation: React.FC<Props> = ({ requirements, participation }) => {
  const { minPosts, minReplies } = requirements;

  const showMinPosts = minPosts > 0;
  const showMinReplies = minReplies > 0;

  const hasParticipationRequirement = minPosts > 0 || minReplies > 0;

  if (!hasParticipationRequirement) return null;

  return (
    <div className="float-right w-fit text-sm text-center">
      Participation
      <table
        style={
          { minWidth: 0, width: 96 } /* There are page styles that override the tailwind classes */
        }
      >
        <tbody>
          <TopTableDivider />
          {showMinPosts && (
            <ParticipationState
              target={minPosts}
              current={participation.posts}
              status={participation.posts >= minPosts ? 'complete' : 'incomplete'}
            >
              Post
            </ParticipationState>
          )}
          {showMinReplies && (
            <ParticipationState
              target={minReplies}
              current={participation.replies}
              status={participation.replies >= minReplies ? 'complete' : 'incomplete'}
            >
              Reply
            </ParticipationState>
          )}
        </tbody>
      </table>
    </div>
  );
};

const ParticipationState: React.FC<{
  target: number;
  current: number;
  status: 'complete' | 'incomplete' | '';
  children: React.ReactNode;
}> = ({ children, target, current, status }) => {
  // There are some page-styles inherited which prevent our tailwind classes from working
  const tailwindTablePageReset = {
    minWidth: 0,
    maxWidth: 48,
    padding: '0px 3px',
  };

  return (
    <tr className="dark:text-white px-2 m-2 text-sm">
      <td style={tailwindTablePageReset} className="border border-Border-border-active">
        {children}
      </td>
      <td className="text-center border border-Border-border-active" style={tailwindTablePageReset}>
        {current < target && `${current}/${target}`}
        {current >= target && `✅`}
      </td>
    </tr>
  );
};

const TopTableDivider: React.FC = () => {
  return (
    <tr
      style={{
        padding: 0,
        border: 0,
        height: 3,
      }}
    >
      <td
        style={{
          padding: 0,
          border: 0,
          height: 3,
        }}
        colSpan={2}
      >
        <div className="rounded-sm border-t-2 border-delivery-primary"></div>
      </td>
    </tr>
  );
};
