import React, { useState } from 'react';

interface Props {
  onPost: (content: string) => void;
  autoFocus?: boolean;
}
export const CreatePost: React.FC<Props> = ({ onPost, autoFocus }) => {
  const [content, setContent] = useState('');
  const expanded = content && content.length > 0;
  const canPost = content && content.length > 10;
  const sizeClass = expanded ? 'h-24 overflow-auto' : 'h-10 overflow-hidden resize-none';

  const onPostClick = () => {
    onPost(content);
    setContent('');
  };

  return (
    <div>
      <textarea
        autoFocus={autoFocus}
        placeholder="Write a post..."
        className={`${sizeClass} transition-[height] w-full rounded-sm`}
        value={content}
        onChange={(e) => setContent(e.target.value)}
      />
      {canPost && <button onClick={onPostClick}>Post</button>}
    </div>
  );
};
