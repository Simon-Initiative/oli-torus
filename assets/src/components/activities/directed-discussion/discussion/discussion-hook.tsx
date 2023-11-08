import { useEffect, useState } from 'react';
import * as DiscussionService from './discussion-service';

export const useDiscussion = (sectionSlug: string | undefined, resourceId: number) => {
  const [posts, setPosts] = useState<DiscussionService.ThreadedPost[]>([]);
  const [currentUserId, setCurrentUserId] = useState<number | undefined>(undefined);
  const [loaded, setLoaded] = useState(false);

  const refreshPosts = () => {
    if (!sectionSlug || !resourceId) return;
    return DiscussionService.getPosts(sectionSlug, String(resourceId)).then((response) => {
      setLoaded(true);
      setPosts(response.threadedPosts);
      setCurrentUserId(response.currentUserId);
    });
  };

  const deletePost = (postId: number) => {
    if (!sectionSlug) return;
    return DiscussionService.deletePost(sectionSlug, String(resourceId), postId).then(refreshPosts);
  };

  const addPost = (content: string, parentId?: number) => {
    if (!sectionSlug) return;
    // TODO, don't reload all posts, just add the new one
    return DiscussionService.writePost(sectionSlug, String(resourceId), content, parentId).then(
      refreshPosts,
    );
  };

  useEffect(() => {
    refreshPosts();
    // TODO - subscribe to PubSub channel
  }, [sectionSlug, resourceId]);

  return { loaded, posts, addPost, currentUserId, deletePost };
};
