import { useEffect, useState } from 'react';
import { ThreadedPost, getPosts } from './discussion-service';

export const useDiscussion = (sectionSlug: string | undefined, resourceId: number) => {
  const [posts, setPosts] = useState<ThreadedPost[]>([]);
  const [loaded, setLoaded] = useState(false);

  const addPost = () => true;

  useEffect(() => {
    if(!sectionSlug || !resourceId) return;
    getPosts(sectionSlug, String(resourceId)).then((posts) => {
      setLoaded(true);
      setPosts(posts);
    });
    // TODO - subscribe to PubSub channel
  }, [sectionSlug, resourceId]);

  return { loaded, posts, addPost };
};
