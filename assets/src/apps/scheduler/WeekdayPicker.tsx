import React from 'react';

const weekdayLabels = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

interface WeekDayPickerProps {
  weekdays: boolean[];
  onChange: (weekdays: boolean[]) => void;
}

export const WeekDayPicker: React.FC<WeekDayPickerProps> = ({ weekdays, onChange }) => {
  return (
    <ul className="ml-4">
      {weekdays.map((day, index) => (
        <li key={index}>
          <div className="form-check">
            <input
              onChange={(e) => {
                const newWeekdays = [...weekdays];
                newWeekdays[index] = e.target.checked;
                onChange(newWeekdays);
              }}
              className="form-check-input appearance-none h-4 w-4 border border-gray-300 rounded-sm bg-white checked:bg-blue-600 checked:border-blue-600 focus:outline-none transition duration-200 mt-1 align-top bg-no-repeat bg-center bg-contain float-left mr-2 cursor-pointer"
              type="checkbox"
              checked={weekdays[index]}
              id={`weekday${index}`}
            />
            <label className="form-check-label inline-block " htmlFor={`weekday${index}`}>
              {weekdayLabels[index]}
            </label>
          </div>
        </li>
      ))}
    </ul>
  );
};
