import { useEffect, useState } from 'react';
import { ThreadedPost, getPosts, writePost } from './discussion-service';

export const useDiscussion = (sectionSlug: string | undefined, resourceId: number) => {
  const [posts, setPosts] = useState<ThreadedPost[]>([]);
  const [loaded, setLoaded] = useState(false);

  const refreshPosts = () => {
    if (!sectionSlug || !resourceId) return;
    getPosts(sectionSlug, String(resourceId)).then((posts) => {
      setLoaded(true);
      setPosts(posts);
    });
  };

  const addPost = (content: string, parentId?: number) => {
    if (!sectionSlug) return;
    // TODO, don't reload all posts, just add the new one
    writePost(sectionSlug, String(resourceId), content, parentId).then(refreshPosts);
  };

  useEffect(() => {
    refreshPosts();
    // TODO - subscribe to PubSub channel
  }, [sectionSlug, resourceId]);

  return { loaded, posts, addPost };
};
