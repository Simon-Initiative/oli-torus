import { DDParticipationDefinition } from '../schema';
import { ThreadedPost } from './discussion-service';

export interface CurrentParticipation {
  posts: number;
  replies: number;
  canPost: boolean;
  canReply: boolean;
}

const MAX_POSTS = 1000;
const MAX_REPLIES = 1000;

const flatPosts = (posts: ThreadedPost[]): ThreadedPost[] => {
  const allPosts: ThreadedPost[] = [];

  posts.forEach((post) => {
    allPosts.push(post);
    if (post.children) {
      allPosts.push(...flatPosts(post.children));
    }
  });

  return allPosts;
};

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

  const canPost =
    (requirements.maxPosts === 0 || userPosts.length < requirements.maxPosts) &&
    userPosts.length < MAX_POSTS;

  const canReply =
    (requirements.maxReplies === 0 || replies.length < requirements.maxReplies) &&
    replies.length < MAX_REPLIES;

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
