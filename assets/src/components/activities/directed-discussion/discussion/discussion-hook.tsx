import { useEffect, useState } from 'react';
import {
  PostCreatedMessage,
  PostDeletedMessage,
  connectToDiscussionChannel,
} from './discussion-channel';
import * as DiscussionService from './discussion-service';
import { mergePost, removeFromPosts } from './post-util';

export const useDiscussion = (sectionSlug: string | undefined, resourceId?: number) => {
  /* Posts are stored in a tree structure, with each post having a list of children. This array will have the
     top level posts in it. */
  const [posts, setPosts] = useState<DiscussionService.ThreadedPost[]>([]);

  /* The current user id is used to determine if the current user is the author of a post. */
  const [currentUserId, setCurrentUserId] = useState<number | undefined>(undefined);

  /* The loadong flag is used to determine if the posts have been loaded from the server yet. */
  const [loading, setLoading] = useState(false);

  /* Given a postId, remove it from our internal list of posts. */
  const removePost = (postId: number) => {
    setPosts(removeFromPosts(postId));
  };

  /* Take a post and merge it into the existing posts */
  const addPost = (post: DiscussionService.Post) => {
    const tp = DiscussionService.postToThreadedPost(post);
    setPosts(mergePost(tp));
  };

  /* Make an API call to reload the full list of posts from the server */
  const refreshPosts = () => {
    if (!sectionSlug || !resourceId) return;
    setLoading(true);
    return DiscussionService.getPosts(sectionSlug, String(resourceId)).then((response) => {
      setLoading(false);
      setPosts(response.threadedPosts);
      setCurrentUserId(response.currentUserId);
    });
  };

  /* Make an API call to delete a post and remove it from our internal state. */
  const deletePost = (postId: number) => {
    if (!sectionSlug) return;
    setLoading(true);
    return DiscussionService.deletePost(sectionSlug, String(resourceId), postId).then(() => {
      setLoading(false);
      removePost(postId);
    });
  };

  /* Make an API call to create a new post and add it to our internal state. */
  const createNewPost = (content: string, parentId?: number) => {
    if (!sectionSlug) return;
    setLoading(true);
    return DiscussionService.createPost(sectionSlug, String(resourceId), content, parentId).then(
      (postResponse) => {
        setLoading(false);
        switch (postResponse.result) {
          case 'success':
            addPost(postResponse.post);
            break;
          case 'error':
            console.error('Error creating post');
            break;
        }
      },
    );
  };

  useEffect(() => {
    if (!sectionSlug) return;

    // Load the initial set of posts.
    refreshPosts();

    // Connect & subscribe to the discussion channel to get realtime updates
    const channel = resourceId && connectToDiscussionChannel(sectionSlug, resourceId);

    channel.join().receive('ok', (e: any) => {
      console.log('Joined channel', e);
    });

    channel.on('post_created', (event: PostCreatedMessage) => {
      console.info('Remote post Created', event.post);
      addPost(event.post);
    });

    channel.on('post_deleted', (event: PostDeletedMessage) => {
      console.info('Post Deleted');
      console.info(event);
      removePost(event.post_id);
    });

    channel.on('post_edited', (event: any) => {
      console.info('Post Deleted');
      console.info(event);
    });

    return () => {
      channel.leave();
    };
  }, [sectionSlug, resourceId]);

  return { loading, posts, addPost: createNewPost, currentUserId, deletePost, refreshPosts };
};
