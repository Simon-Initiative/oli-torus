import { DDParticipationDefinition } from '../schema';
import { ThreadedPost } from './discussion-service';
import { flatPosts } from './post-util';

export interface CurrentParticipation {
  posts: number;
  replies: number;
  canPost: boolean;
  canReply: boolean;
}

const MAX_POSTS = 1000;
const MAX_REPLIES = 1000;

export const calculateParticipation = (
  requirements: DDParticipationDefinition,
  posts: ThreadedPost[],
  userId?: number,
): CurrentParticipation => {
  if (!userId) return { posts: 0, replies: 0, canPost: false, canReply: false };
  const userPosts = posts.filter((post) => post.parent_post_id === null && post.user_id === userId);
  const allPosts = flatPosts(posts);
  const replies = allPosts.filter(
    (post: ThreadedPost) => post.parent_post_id !== null && post.user_id === userId,
  );

  const pastPostDeadline =
    requirements.postDeadline && Date.now() > new Date(requirements.postDeadline).getTime();

  const pastReplyDeadline =
    requirements.replyDeadline && Date.now() > new Date(requirements.replyDeadline).getTime();

  const canPost =
    (requirements.maxPosts === 0 || userPosts.length < requirements.maxPosts) &&
    userPosts.length < MAX_POSTS &&
    !pastPostDeadline;

  const canReply =
    (requirements.maxReplies === 0 || replies.length < requirements.maxReplies) &&
    replies.length < MAX_REPLIES &&
    !pastReplyDeadline;

  return {
    canPost,
    canReply,
    posts: userPosts.length,
    replies: replies.length,
  };
};

export const countWords = (text: string) => {
  const words = text.trim().split(/\s+/).length;
  return words;
};
