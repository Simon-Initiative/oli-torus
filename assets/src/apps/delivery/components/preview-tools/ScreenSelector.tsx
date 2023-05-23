/* eslint-disable no-prototype-builtins */

/* eslint-disable react/prop-types */
import React, { useMemo } from 'react';
import { useSelector } from 'react-redux';
import { sortScreens } from '../../../authoring/components/Flowchart/screens/screen-utils';
import { IActivity, selectAllActivities } from '../../store/features/activities/slice';
import { selectDeliveryContentMode } from '../../store/features/page/slice';

interface ScreenSelectorProps {
  sequence: any;
  navigate: any;
  currentActivity: any;
}
const ScreenSelector: React.FC<ScreenSelectorProps> = ({
  sequence,
  navigate,
  currentActivity,
}: ScreenSelectorProps) => {
  const applicationMode = useSelector(selectDeliveryContentMode);
  const isFlowchartMode = applicationMode === 'flowchart';
  return isFlowchartMode ? (
    <FlowchartScreenSelector
      sequence={sequence}
      navigate={navigate}
      currentActivity={currentActivity}
    />
  ) : (
    <AdvancedScreenSelector
      sequence={sequence}
      navigate={navigate}
      currentActivity={currentActivity}
    />
  );
};

export const FlowchartScreenSelector: React.FC<ScreenSelectorProps> = ({
  sequence,
  navigate,
  currentActivity,
}) => {
  const activities = useSelector(selectAllActivities);
  const sortedActivities = useMemo(() => {
    const firstScreen = activities.find((a) => a.id === sequence[0]?.sequenceId);

    return sortScreens(activities, firstScreen);
  }, [activities, sequence]);

  const onSelect = (activity: IActivity) => (e: React.MouseEvent) => {
    e.preventDefault();
    navigate(activity.id);
  };

  return (
    <div className={`preview-tools-view`}>
      <ol className="list-group list-group-flush">
        {sortedActivities.map((s: IActivity, i: number) => {
          return (
            <li key={i} className={`list-group-item pl-5 py-1 list-group-item-action`}>
              <a
                href=""
                className={currentActivity?.id === s.id ? 'selected' : ''}
                onClick={onSelect(s)}
              >
                {s.title}
              </a>
            </li>
          );
        })}
      </ol>
    </div>
  );
};

export const AdvancedScreenSelector: React.FC<ScreenSelectorProps> = ({
  sequence,
  navigate,
  currentActivity,
}) => {
  return (
    <div className={`preview-tools-view`}>
      <ol className="list-group list-group-flush">
        {sequence?.map((s: any, i: number) => {
          return (
            <li
              key={i}
              className={`list-group-item pl-5 py-1 list-group-item-action${
                currentActivity?.id === s.sequenceId ? ' active' : ''
              }`}
            >
              <a
                href=""
                className={currentActivity?.id === s.sequenceId ? 'selected' : ''}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(s.sequenceId);
                }}
              >
                {s.sequenceName}
              </a>
            </li>
          );
        })}
      </ol>
    </div>
  );
};

export default ScreenSelector;
