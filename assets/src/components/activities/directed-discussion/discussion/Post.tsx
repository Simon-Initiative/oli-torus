import React from 'react';
import { formatDate } from 'components/activities/common/utils';
import { useToggle } from 'components/hooks/useToggle';
import { LinkButton } from 'components/misc/Button';
import { CreatePost } from './CreatePost';
import { PostList } from './DiscussionThread';
import { DiscussionPortrait } from './Portrait';
import { OnDeletePostHandler, OnPostHandler, ThreadedPost } from './discussion-service';

export const Post: React.FC<{
  currentUserId: number;
  post: ThreadedPost;
  onPost: OnPostHandler;
  onDeletePost: OnDeletePostHandler;
  canPost: boolean;
  focusId: number | null;
  maxWords: number;
}> = ({ post, onPost, currentUserId, onDeletePost, canPost, maxWords, focusId }) => {
  const onPostReply = (content: string) => {
    onPost(content, post.id);
  };

  const canDelete = currentUserId === post.user_id && post.children.length === 0;
  const focused = post.id === focusId;

  return (
    <>
      <div className={`mb-4 mt-2 ${focused && 'border-primary border-2 p-4'}`}>
        <div className="flex flex-row items-start gap-3 relative">
          <DiscussionPortrait />
          <div className="text-xs">
            <b>{post.user_name}</b>
            {post.parentAuthorName && (
              <>
                &nbsp;replied&nbsp;
                <b>{post.parentAuthorName}</b>
              </>
            )}
            <br />
            {formatDate(post.updated_at)}
            {canDelete && <DeleteLink onClick={() => onDeletePost(post.id)} />}
          </div>
        </div>

        <div className="mt-4 ml-15">{post.content}</div>
      </div>

      <div>
        {canPost && (
          <CreatePost
            readonly={!canPost}
            onPost={onPostReply}
            autoFocus={false}
            placeholder="Reply..."
            maxWords={maxWords}
          />
        )}
        <div className="ml-12 mt-25">
          <PostList
            focusId={focusId}
            maxWords={maxWords}
            posts={post.children}
            onPost={onPost}
            currentUserId={currentUserId}
            onDeletePost={onDeletePost}
            canPost={canPost}
          />
        </div>
      </div>
    </>
  );
};

const DeleteLink: React.FC<{ onClick: () => void }> = ({ onClick }) => {
  const [confirm, toggleConfirm] = useToggle(false);
  return (
    <div className="sm:absolute sm:right-1 sm:top-1 mt-1 sm:mt-0">
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
