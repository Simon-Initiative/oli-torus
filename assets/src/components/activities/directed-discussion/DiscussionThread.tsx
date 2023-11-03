import React from 'react';
import { ThreadedPost } from './discussion-service';

interface Props {
  posts: ThreadedPost[];
}

export const DiscussionThread: React.FC<Props> = ({ posts }) => {
  // if (!enabled) {
  //   return <DiscussionPreview />;
  // }
  return (
    <div>
      <h1>Discussion Thread</h1>
      <PostList posts={posts} />
    </div>
  );
};

const PostList: React.FC<{ posts: ThreadedPost[] }> = ({ posts }) => {
  return (
    <>
      {posts.map((post) => (
        <Post key={post.id} post={post} />
      ))}
    </>
  );
};

const Post: React.FC<{ post: ThreadedPost }> = ({ post }) => {
  return (
    <div className="mb-4">
      <div>
        {post.user_name}
        Replies: {post.replies_count}
        {post.updated_at}
      </div>
      <div>{post.content}</div>
      <div className="ml-4">
        <PostList posts={post.children} />
      </div>
    </div>
  );
};

const DiscussionPreview: React.FC = () => {
  // TODO - give a better preview
  return <div>Discussions not available in preview.</div>;
};
