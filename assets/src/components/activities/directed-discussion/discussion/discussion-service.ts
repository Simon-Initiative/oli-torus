export interface Post {
  id: number;
  content: string;
  user_name: string;
  updated_at: string;
  user_id: number;
  parent_post_id: null | number;
  thread_root_id: null | number;
  anonymous: false;
}

interface DiscussionResult {
  posts: Post[];
  current_user: number;
}

export interface ThreadedPost extends Post {
  children: ThreadedPost[];
  timestamp: number;
  parentAuthorName: null | string;
}

export interface CreatePostResponseSuccess {
  post: Post;
  result: 'success' | 'error';
}

export interface CreatePostResponseError {
  result: 'error';
}

export const deletePost = (sectionSlug: string, resourceId: string, postId: number) => {
  return fetch(`/api/v1/discussion/${sectionSlug}/${resourceId}/${postId}`, {
    method: 'DELETE',
  }).then((r) => r.json());
};

export const createPost = (
  sectionSlug: string,
  resourceId: string,
  content: string,
  parent?: number,
): Promise<CreatePostResponseSuccess | CreatePostResponseError> => {
  const body = {
    content,
    parent_post_id: parent,
  };
  return fetch(`/api/v1/discussion/${sectionSlug}/${resourceId}`, {
    method: 'POST',
    body: JSON.stringify(body),
    headers: {
      'Content-Type': 'application/json',
    },
  }).then((r) => r.json());
};

export const postToThreadedPost = (post: Post): ThreadedPost => ({
  ...post,
  children: [],
  timestamp: Date.parse(post.updated_at),
  parentAuthorName: null,
});

export const getPosts = (sectionSlug: string, resourceId: string) => {
  return fetch(`/api/v1/discussion/${sectionSlug}/${resourceId}`)
    .then((r) => r.json())
    .then(threadPosts);
};

const sortPosts = (a: ThreadedPost, b: ThreadedPost) => {
  if (a.timestamp > b.timestamp) {
    return -1;
  }
  if (a.timestamp < b.timestamp) {
    return 1;
  }
  return 0;
};

const threadPosts = (
  response: DiscussionResult,
): {
  currentUserId: number;
  threadedPosts: ThreadedPost[];
} => {
  const posts: ThreadedPost[] = response.posts.map(postToThreadedPost).sort(sortPosts);

  const threadedPosts = posts.reduce((threads, post) => {
    if (post.parent_post_id) {
      const parent = posts.find((thread) => thread.id === post.parent_post_id);
      post.parentAuthorName = parent?.user_name || null;
      if (parent) {
        parent.children.push(post);
      }
    } else {
      threads.push(post);
    }
    return threads;
  }, [] as ThreadedPost[]);
  return {
    currentUserId: response.current_user,
    threadedPosts,
  };
};

export type OnPostHandler = (content: string, parentPost?: number) => void;
export type OnDeletePostHandler = (postId: number) => void;
