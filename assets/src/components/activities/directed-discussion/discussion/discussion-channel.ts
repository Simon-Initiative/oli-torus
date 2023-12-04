import { Socket } from 'phoenix';
import { Post } from './discussion-service';

/* Code relevant to communicating with the torus server over the real time directed_discussion channel */

export interface PostDeletedMessage {
  post_id: number;
  user_id: number;
}
export interface PostCreatedMessage {
  post: Post;
  user_id: number;
}

export const channelName = (sectionSlug: string, resourceId: number) =>
  `directed_discussion:${sectionSlug}:${resourceId}`;

export const connectToDiscussionChannel = (sectionSlug: string, resourceId: number) => {
  const socket = new Socket('/v1/api/state', { params: { token: (window as any).userToken } });

  socket.onError(function (error: any) {
    console.error('Socket failed, an error occurred', error);
    socket.disconnect();
  });

  socket.connect();

  console.info('Subscribing to', `collab_space_${sectionSlug}_${resourceId}`);
  const channel = socket.channel(channelName(sectionSlug, resourceId), {
    params: { token: (window as any).userToken },
  });

  return channel;
};
