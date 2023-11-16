import React, { useMemo } from 'react';
import { Post } from './Post';
import { SearchResultPost } from './SearchResultPost';
import { ThreadedPost } from './discussion-service';
import { flatPosts } from './post-util';

interface Props {
  searchTerm: string;
  posts: ThreadedPost[];
  onFocus: (postId: number) => void;
}

const searchFunc = (searchTerm: string) => (post: ThreadedPost) => {
  const { content } = post;
  return content.includes(searchTerm);
};

export const DiscussionSearchResults: React.FC<Props> = ({ onFocus, searchTerm, posts }) => {
  const filteredPosts = useMemo(() => {
    const allPosts = flatPosts(posts);

    const filteredPosts = allPosts.filter(searchFunc(searchTerm));
    return filteredPosts;
  }, [searchTerm, posts]);

  if (filteredPosts.length === 0) {
    return <div className="bg-gray-200 p-5 text-center m-4">No Posts Found</div>;
  }

  return (
    <div>
      Results: {filteredPosts.length}
      {filteredPosts.map((post) => (
        <SearchResultPost post={post} onClick={() => onFocus(post.id)} key={post.id} />
      ))}
    </div>
  );
};
