import React from 'react';
import { useSelector } from 'react-redux';
import {
  IActivity,
  selectCurrentActivity,
} from '../../../delivery/store/features/activities/slice';

interface FlowchartSidebarProps {}

export const FlowchartSidebar: React.FC<FlowchartSidebarProps> = () => {
  const selected = useSelector(selectCurrentActivity);
  return (
    <div className="flowchart-sidebar">
      Sidebar
      {selected && <SelectedScreen screen={selected} />}
    </div>
  );
};

const SelectedScreen: React.FC<{ screen: IActivity }> = ({ screen }) => {
  return (
    <div>
      <h3>{screen.title}</h3>
      <b>rules:</b>
      <ol>
        {screen.authoring?.flowchart?.paths.map((path) => (
          <li key={path.id}>
            <pre>{JSON.stringify(path, null, 2)}</pre>
          </li>
        ))}
      </ol>
    </div>
  );
};
