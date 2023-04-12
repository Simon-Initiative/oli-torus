import React, { useState, useCallback } from 'react';
import { ScreenIcon } from '../chart-components/ScreenIcon';
import { ScreenButton } from '../chart-components/ScreenButton';
import { ScreenEditIcon } from '../chart-components/ScreenEditIcon';

interface ScreenTitleProps {
  screenType?: string;
  title: string;
  validated?: boolean;
  onChange: (newTitle: string) => void;
}

const ScreenTitle: React.FC<ScreenTitleProps> = ({ screenType, title, validated, onChange }) => {
  const [editingTitle, setEditingTitle] = useState(false);
  const [newTitle, setNewTitle] = useState(title);

  const handleTitleClick = useCallback(() => {
    setEditingTitle(true);
  }, []);

  const handleTitleChange = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    setNewTitle(event.target.value);
  }, []);

  const handleTitleSubmit = useCallback(() => {
    onChange(newTitle);
    setEditingTitle(false);
  }, [newTitle, onChange]);

  const handleRenameButtonClick = useCallback(() => {
    if (editingTitle) {
      handleTitleSubmit();
    } else {
      setEditingTitle(true);
    }
  }, [editingTitle, handleTitleSubmit]);

  const handleKeyPress = useCallback(
    (event: React.KeyboardEvent<HTMLInputElement>) => {
      if (event.key === 'Enter') {
        handleTitleSubmit();
      }
    },
    [handleTitleSubmit],
  );

  return (
    <div className="screen-title">
      <ScreenIcon screenType={screenType} />
      {editingTitle ? (
        <input
          className="form-control"
          type="text"
          value={newTitle}
          autoFocus={true}
          onChange={handleTitleChange}
          onBlur={handleTitleSubmit}
          onKeyPress={handleKeyPress}
        />
      ) : (
        <span onClick={handleTitleClick}>{newTitle}</span>
      )}
      <ScreenButton tooltip="Rename Screen" onClick={handleRenameButtonClick}>
        <ScreenEditIcon />
      </ScreenButton>
    </div>
  );
};

export default ScreenTitle;
