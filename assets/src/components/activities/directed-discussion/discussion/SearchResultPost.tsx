import React from 'react';
import { formatDate } from 'components/activities/common/utils';
import { DiscussionPortrait } from './Portrait';
import { ThreadedPost } from './discussion-service';

export const SearchResultPost: React.FC<{
  post: ThreadedPost;
  onClick: () => void;
}> = ({ post, onClick }) => {
  return (
    <div className="cursor-pointer mb-4 mt-2 p-3 bg-gray-200" onClick={onClick}>
      <div className="flex flex-row items-start gap-3 relative">
        <DiscussionPortrait showBullet={false} />
        <div className="text-xs">
          <b>{post.user_name}</b>
          {post.parent_post_id && (
            <>
              <span className="mx-2 text-gray-400">replied</span>
              <b>XXX</b>
            </>
          )}
          <br />
          {formatDate(post.updated_at)}
        </div>
      </div>

      <div className="mt-4 ml-15">{post.content}</div>
    </div>
  );
};
