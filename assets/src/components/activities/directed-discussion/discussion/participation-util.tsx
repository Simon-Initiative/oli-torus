import { DDParticipationDefinition } from '../schema';
import { Post } from './discussion-service';

export interface CurrentParticipation {
  posts: number;
  replies: number;
  canPost: boolean;
  canReply: boolean;
}

export const calculateParticipation = (
  requirements: DDParticipationDefinition,
  posts: Post[],
  userId?: number,
): CurrentParticipation => {
  if (!userId) return { posts: 0, replies: 0, canPost: false, canReply: false };
  const userPosts = posts.filter((post) => post.parent_post_id === null && post.user_id === userId);
  const replies = posts.filter((post) => post.parent_post_id !== null && post.user_id === userId);

  const canPost = requirements.maxPosts === 0 || userPosts.length < requirements.maxPosts;
  const canReply = requirements.maxReplies === 0 || replies.length < requirements.maxReplies;

  return {
    canPost,
    canReply,
    posts: userPosts.length,
    replies: replies.length,
  };
};

