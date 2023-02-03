import React from 'react';
import { useSelector } from 'react-redux';
import { getSchedule, getSelectedItem } from './schedule-selectors';
import { getScheduleItem, ScheduleItemType } from './scheduler-slice';

export const ScheduleSlideout: React.FC<{ onModification: () => void }> = ({ onModification }) => {
  const selectedItem = useSelector(getSelectedItem);
  const schedule = useSelector(getSchedule);
  if (!selectedItem) return null;
  return (
    <div>
      {selectedItem.title} {selectedItem.numbering_index}
      {selectedItem.children
        .map((itemId) => getScheduleItem(itemId, schedule))
        .filter((child) => child?.resource_type_id === ScheduleItemType.Page)
        .map((child) => (
          <li key={child?.resource_id}>
            {child?.title} {child?.numbering_index}
          </li>
        ))}
    </div>
  );
};
