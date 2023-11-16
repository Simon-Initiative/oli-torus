import React, { useState } from 'react';
import { useToggle } from 'components/hooks/useToggle';
import { InputClasses } from './DiscussionStyles';

type SortType = 'newest' | 'popularity';

interface Props {
  onSearch?: (search: string) => void;
  onSort?: (sort: SortType) => void;
}

export const DiscussionSearchSortBar: React.FC<Props> = ({ onSearch }) => {
  const [searchFieldOpen, , openSearchField] = useToggle(false);
  const [searchTerm, setSearchTerm] = useState('');

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      onSearch && onSearch(searchTerm);
    }
  };

  return (
    <div className="flex flex-row justify-end gap-2">
      {searchFieldOpen && (
        <input
          onKeyDown={onKeyDown}
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Search..."
          autoFocus={true}
          className={`flex-grow h-[30px] mr-3 ${InputClasses}`}
          type="text"
        />
      )}
      {searchFieldOpen || (
        <button className="flex-grow-0" onClick={openSearchField}>
          Search
        </button>
      )}
      <button className="flex-grow-0">Newest</button>
      <button className="flex-grow-0">Popularity</button>
    </div>
  );
};
