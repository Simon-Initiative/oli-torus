import React from 'react';
import { CreatePost } from './CreatePost';
import { Post } from './Post';
import { OnDeletePostHandler, OnPostHandler, ThreadedPost } from './discussion-service';

interface Props {
  posts: ThreadedPost[];
  onPost: OnPostHandler;
  currentUserId: number;
  onDeletePost: OnDeletePostHandler;
  canPost: boolean;
  canReply: boolean;
}

export const DiscussionThread: React.FC<Props> = ({
  posts,
  onPost,
  currentUserId,
  onDeletePost,
  canPost,
  canReply,
}) => {
  // if (!enabled) {
  //   return <DiscussionPreview />;
  // }
  return (
    <div>
      <h1>Discussion Thread</h1>
      {canPost && <CreatePost onPost={onPost} />}
      <PostList
        posts={posts}
        onPost={onPost}
        currentUserId={currentUserId}
        onDeletePost={onDeletePost}
        canPost={canReply}
      />
    </div>
  );
};

export const PostList: React.FC<{
  posts: ThreadedPost[];
  onPost: OnPostHandler;
  currentUserId: number;
  onDeletePost: OnDeletePostHandler;
  canPost: boolean;
}> = ({ posts, onPost, currentUserId, onDeletePost, canPost }) => {
  return (
    <>
      {posts.map((post) => (
        <Post
          key={post.id}
          post={post}
          onPost={onPost}
          currentUserId={currentUserId}
          onDeletePost={onDeletePost}
          canPost={canPost}
        />
      ))}
    </>
  );
};

// const DiscussionPreview: React.FC = () => {
//   // TODO - give a better preview
//   return <div>Discussions not available in preview.</div>;
// };
