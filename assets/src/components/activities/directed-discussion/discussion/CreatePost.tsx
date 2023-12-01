import React, { useState } from 'react';
import { Button } from 'components/misc/Button';
import { InputClasses } from './DiscussionStyles';
import { countWords } from './participation-util';

interface Props {
  onPost: (content: string) => void;
  autoFocus?: boolean;
  placeholder?: string;
  maxWords: number;
  readonly: boolean;
}
export const CreatePost: React.FC<Props> = ({
  readonly,
  onPost,
  autoFocus,
  placeholder,
  maxWords,
}) => {
  const [content, setContent] = useState('');
  const wordsCount = countWords(content);
  const expanded = content && content.length > 0;
  const canPost = content && content.length > 3;
  const sizeClass = expanded ? 'h-24 overflow-auto' : 'h-[30px] overflow-hidden resize-none';

  const onPostClick = () => {
    if (readonly) return;
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
        className={`${sizeClass} ${InputClasses}`}
        value={content}
        onChange={(e) => setContent(e.target.value)}
        disabled={readonly}
      />
      {expanded && (
        <div className="flex justify-between items-center mt-1 mb-2">
          <div className="flex-grow" />
          {hasWordLimit && (
            <span className={`mx-2 ${overWordLimit && 'text-red-600'}`}>
              {overWordLimit && 'Over max word limit: '}
              {wordsCount} / {maxWords}
            </span>
          )}
          <Button disabled={!canPost || overWordLimit || readonly} onClick={onPostClick}>
            Post
          </Button>
        </div>
      )}
    </div>
  );
};
