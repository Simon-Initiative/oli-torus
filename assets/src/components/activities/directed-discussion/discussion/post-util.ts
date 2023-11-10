import { ThreadedPost } from './discussion-service';

export const removeFromPosts =
  (postId: number) =>
  (posts: ThreadedPost[]): ThreadedPost[] => {
    const filteredPosts = posts.filter((p) => p.id !== postId);
    return filteredPosts.map((p) => ({
      ...p,
      children: removeFromPosts(postId)(p.children),
    }));
  };

/* Adds post into the right place of existingPosts based on parent/child relationship
 * This is a curried function so you can setPosts(mergePost(post))
 */
export const mergePost = (post: ThreadedPost) => (existingPosts: ThreadedPost[]) => {
  if (post.parent_post_id) {
    existingPosts = addChildPostToParent(existingPosts, post);
  } else {
    existingPosts = addPostToPostList(post, existingPosts);
  }
  return [...existingPosts];
};

const addChildPostToParent = (posts: ThreadedPost[], child: ThreadedPost) => {
  const parent = posts.find((p) => p.id === child.parent_post_id);
  if (parent) {
    parent.children = addPostToPostList(child, parent.children);
  }
  posts.forEach((p) => {
    if (p.children) {
      p.children = addChildPostToParent(p.children, child);
    }
  });
  return posts;
};

// Add a post to the list of posts, if it's not already there
const addPostToPostList = (post: ThreadedPost, posts: ThreadedPost[]) => {
  if (posts.find((p) => p.id === post.id)) return posts; // Already in
  return [post, ...posts];
};
