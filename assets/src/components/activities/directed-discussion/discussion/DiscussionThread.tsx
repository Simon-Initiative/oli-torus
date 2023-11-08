import React from 'react';
import { useToggle } from 'components/hooks/useToggle';
import { LinkButton } from 'components/misc/Button';
import { CreatePost } from './CreatePost';
import { ThreadedPost } from './discussion-service';

type OnPostHandler = (content: string, parentPost?: number) => void;

interface Props {
  posts: ThreadedPost[];
  onPost: OnPostHandler;
}

export const DiscussionThread: React.FC<Props> = ({ posts, onPost }) => {
  // if (!enabled) {
  //   return <DiscussionPreview />;
  // }
  return (
    <div>
      <h1>Discussion Thread</h1>
      <CreatePost onPost={onPost} />
      <PostList posts={posts} onPost={onPost} />
    </div>
  );
};

const PostList: React.FC<{ posts: ThreadedPost[]; onPost: OnPostHandler }> = ({
  posts,
  onPost,
}) => {
  return (
    <>
      {posts.map((post) => (
        <Post key={post.id} post={post} onPost={onPost} />
      ))}
    </>
  );
};

const Post: React.FC<{ post: ThreadedPost; onPost: OnPostHandler }> = ({ post, onPost }) => {
  const [replyOpen, toggleReplyOpen] = useToggle(false);
  const onPostReply = (content: string) => {
    toggleReplyOpen();
    onPost(content, post.id);
  };
  return (
    <div className="mb-4">
      <div>
        {post.user_name}
        Replies: {post.replies_count}
        {post.updated_at}
      </div>
      <div>{post.content}</div>
      {replyOpen || <LinkButton onClick={toggleReplyOpen}>Reply</LinkButton>}
      {replyOpen && <CreatePost onPost={onPostReply} autoFocus={true} />}
      <div className="ml-4">
        <PostList posts={post.children} onPost={onPost} />
      </div>
    </div>
  );
};

const DiscussionPreview: React.FC = () => {
  // TODO - give a better preview
  return <div>Discussions not available in preview.</div>;
};
