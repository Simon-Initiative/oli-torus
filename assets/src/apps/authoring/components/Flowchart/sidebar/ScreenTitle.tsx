import React, { useState, useCallback } from 'react';
import { ScreenIcon } from '../chart-components/ScreenIcon';
import { ScreenButton } from '../chart-components/ScreenButton';
import { ScreenEditIcon } from '../chart-components/ScreenEditIcon';
import { ScreenValidationColors } from '../screen-icons/screen-icons';

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
    if (title !== newTitle) {
      onChange(newTitle);
    }
    setEditingTitle(false);
  }, [newTitle, onChange, title]);

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
    <div className="screen-title" onClick={handleTitleClick}>
      <ScreenIcon
        screenType={screenType}
        bgColor={
          validated ? ScreenValidationColors.VALIDATED : ScreenValidationColors.NOT_VALIDATED
        }
      />
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
        <span>{newTitle}</span>
      )}
      <ScreenButton tooltip="Rename Screen" onClick={handleRenameButtonClick}>
        <ScreenEditIcon />
      </ScreenButton>
    </div>
  );
};

export default ScreenTitle;
