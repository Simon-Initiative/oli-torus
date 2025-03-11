import React, { useMemo, useState } from 'react';
import { useSelector } from 'react-redux';
import { selectAllActivities } from 'apps/delivery/store/features/activities/slice';

interface Props {
  id: string;
  value: number;
  onChange: (value: number) => void;
}

export const SpokeCompletedOption: React.FC<Props> = ({ id, value, onChange }) => {
  const [currentSpokeDestination, setCurrentSpokeDestination] = useState(value);
  const activities = useSelector(selectAllActivities);
  const screens: Record<string, string> = useMemo(() => {
    return activities.reduce((acc, activity, index) => {
      if (index == 0) {
        acc['0'] = '--select hub destination--';
      }

      const filterhubSpokeScreens = activity.content?.partsLayout.find(
        (parts) => parts.type === 'janus-hub-spoke',
      );
      const validScreens = activity.authoring?.flowchart?.screenType !== 'welcome_screen';

      if (!filterhubSpokeScreens && validScreens) {
        return {
          ...acc,
          [activity.id]: activity.title || 'Untitled',
        };
      }
      return acc;
    }, {} as Record<string, string>);
  }, [activities]);
  return (
    <div>
      <label className="form-label">Completed hub destination</label>
      <div>
        <select
          className="form-group custom-select"
          style={{ width: '100%' }}
          value={currentSpokeDestination}
          onChange={(e) => {
            setCurrentSpokeDestination(Number(e.target.value));
            onChange(Number(e.target.value));
          }}
        >
          {Object.keys(screens).map((screenId, index) => (
            <option key={screenId} value={screenId}>
              {screens[screenId]}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
};
