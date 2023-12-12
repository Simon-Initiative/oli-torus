import React, { useState } from 'react';
import { useToggle } from 'components/hooks/useToggle';
import { Icon } from 'components/misc/Icon';
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

  const onSearchClick = () => {
    if (searchFieldOpen) {
      onSearch && onSearch(searchTerm);
    } else {
      openSearchField();
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

      <button className="flex-grow-0" onClick={onSearchClick}>
        <Icon icon="magnifying-glass" />
      </button>

      {/*
      <Button variant="secondary-box" className="flex-grow-0 text-sm rounded-none">
        Newest
      </Button>
      <Button variant="secondary-box" className="flex-grow-0 text-sm rounded-none">
        Popularity
      </Button>
      <SortIcon /> */}
    </div>
  );
};
