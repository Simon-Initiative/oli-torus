interface Post {
  id: number;
  content: string;
  user_name: string;
  updated_at: string;
  user_id: number;
  replies_count: null | number;
  parent_post_id: null | number;
  thread_root_id: null | number;
  anonymous: false;
}

interface DiscussionResult {
  posts: Post[];
}

export interface ThreadedPost extends Post {
  children: ThreadedPost[];
}

export const writePost = (
  sectionSlug: string,
  resourceId: string,
  content: string,
  parent?: number,
) => {
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

export const getPosts = (sectionSlug: string, resourceId: string) => {
  return fetch(`/api/v1/discussion/${sectionSlug}/${resourceId}`)
    .then((r) => r.json())
    .then(threadPosts);
};

const threadPosts = (response: DiscussionResult): ThreadedPost[] => {
  const posts = response.posts.map((post) => ({ ...post, children: [] }));
  const threadedPosts = posts.reduce((threads, post) => {
    if (post.parent_post_id) {
      const parent = threads.find((thread) => thread.id === post.parent_post_id);
      if (parent) {
        parent.children.push(post);
      }
    } else {
      threads.push(post);
    }
    return threads;
  }, [] as ThreadedPost[]);
  return threadedPosts;
};
