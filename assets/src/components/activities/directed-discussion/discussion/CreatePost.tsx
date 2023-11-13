import React, { useState } from 'react';
import { Button } from 'components/misc/Button';
import { countWords } from './participation-util';

interface Props {
  onPost: (content: string) => void;
  autoFocus?: boolean;
  placeholder?: string;
  maxWords: number;
}
export const CreatePost: React.FC<Props> = ({ onPost, autoFocus, placeholder, maxWords }) => {
  const [content, setContent] = useState('');
  const wordsCount = countWords(content);
  const expanded = content && content.length > 0;
  const canPost = content && content.length > 10;
  const sizeClass = expanded ? 'h-24 overflow-auto' : 'h-[30px] overflow-hidden resize-none';

  const onPostClick = () => {
    onPost(content);
    setContent('');
  };

  const hasWordLimit = maxWords > 0;
  const overWordLimit = hasWordLimit && wordsCount > maxWords;

  return (
    <div>
      <textarea
        autoFocus={autoFocus}
        placeholder={placeholder || 'Create your new post...'}
        className={`${sizeClass} mt-2 text-xs transition-[height]  w-full rounded-sm border-gray-300 line-h leading-3`}
        value={content}
        onChange={(e) => setContent(e.target.value)}
      />
      {expanded && (
        <div className="flex justify-between items-center mt-1 mb-2">
          <div className="flex-grow" />
          {hasWordLimit && (
            <span className={`mx-2 ${overWordLimit && "text-red-600"}`}>
              {overWordLimit && 'Over max word limit: '}
              {wordsCount} / {maxWords}
            </span>
          )}
          <Button disabled={!canPost || overWordLimit} onClick={onPostClick}>
            Post
          </Button>
        </div>
      )}
    </div>
  );
};
