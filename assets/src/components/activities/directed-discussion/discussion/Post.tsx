import React from 'react';
import { useToggle } from 'components/hooks/useToggle';
import { LinkButton } from 'components/misc/Button';
import { CreatePost } from './CreatePost';
import { PostList } from './DiscussionThread';
import { OnDeletePostHandler, OnPostHandler, ThreadedPost } from './discussion-service';

export const Post: React.FC<{
  currentUserId: number;
  post: ThreadedPost;
  onPost: OnPostHandler;
  onDeletePost: OnDeletePostHandler;
  canPost: boolean;
}> = ({ post, onPost, currentUserId, onDeletePost, canPost }) => {
  const [replyOpen, toggleReplyOpen] = useToggle(false);
  const onPostReply = (content: string) => {
    toggleReplyOpen();
    onPost(content, post.id);
  };

  const canDelete = currentUserId === post.user_id && post.children.length === 0;

  return (
    <div className="mb-4">
      <div>
        {post.user_name}
        Replies: {post.children.length}
        {post.updated_at}
        {canDelete && <DeleteLink onClick={() => onDeletePost(post.id)} />}
      </div>
      <div>{post.content}</div>
      {canPost && (
        <>
          {replyOpen || <LinkButton onClick={toggleReplyOpen}>Reply</LinkButton>}
          {replyOpen && (
            <div className="ml-4">
              <CreatePost onPost={onPostReply} autoFocus={true} />
            </div>
          )}
        </>
      )}
      <div className="ml-4">
        <PostList
          posts={post.children}
          onPost={onPost}
          currentUserId={currentUserId}
          onDeletePost={onDeletePost}
          canPost={canPost}
        />
      </div>
    </div>
  );
};

const DeleteLink: React.FC<{ onClick: () => void }> = ({ onClick }) => {
  const [confirm, toggleConfirm] = useToggle(false);
  return (
    <div>
      {confirm || <LinkButton onClick={toggleConfirm}>Delete</LinkButton>}
      {confirm && (
        <>
          Are you sure?&nbsp;
          <LinkButton onClick={onClick}>Yes</LinkButton>&nbsp;
          <LinkButton onClick={toggleConfirm}>No</LinkButton>
        </>
      )}
    </div>
  );
};
