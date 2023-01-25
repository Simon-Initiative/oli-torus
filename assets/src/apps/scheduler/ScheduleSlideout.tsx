import React from 'react';
import { useSelector } from 'react-redux';
import { getSelectedItem } from './schedule-selectors';

export const ScheduleSlideout = () => {
  const selectedItem = useSelector(getSelectedItem);
  if (!selectedItem) return null;
  return (
    <div>
      {selectedItem.title} {selectedItem.index}
      {selectedItem.children
        .filter((child) => child.type !== 'container')
        .map((child) => (
          <li key={child.id}>
            {child.title} {child.index}
          </li>
        ))}
    </div>
  );
};
