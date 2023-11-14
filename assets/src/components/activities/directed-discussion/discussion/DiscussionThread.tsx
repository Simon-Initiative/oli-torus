import React from 'react';
import { CreatePost } from './CreatePost';
import { HorizontalRule } from './DiscussionStyles';
import { Post } from './Post';
import { OnDeletePostHandler, OnPostHandler, ThreadedPost } from './discussion-service';

interface Props {
  posts: ThreadedPost[];
  onPost: OnPostHandler;
  currentUserId: number;
  onDeletePost: OnDeletePostHandler;
  canPost: boolean;
  canReply: boolean;
  maxWords: number;
}

export const DiscussionThread: React.FC<Props> = ({
  posts,
  onPost,
  currentUserId,
  onDeletePost,
  canPost,
  canReply,
  maxWords,
}) => {
  // if (!enabled) {
  //   return <DiscussionPreview />;
  // }
  return (
    <div>
      {canPost && (
        <div className="mb-4">
          <HorizontalRule />
          <CreatePost onPost={onPost} maxWords={maxWords} autoFocus={true} />
          <HorizontalRule />
        </div>
      )}
      <PostList
        posts={posts}
        onPost={onPost}
        currentUserId={currentUserId}
        onDeletePost={onDeletePost}
        canPost={canReply}
        maxWords={maxWords}
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
  maxWords: number;
}> = ({ posts, onPost, currentUserId, onDeletePost, canPost, maxWords }) => {
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
          maxWords={maxWords}
        />
      ))}
    </>
  );
};

// const DiscussionPreview: React.FC = () => {
//   // TODO - give a better preview
//   return <div>Discussions not available in preview.</div>;
// };
