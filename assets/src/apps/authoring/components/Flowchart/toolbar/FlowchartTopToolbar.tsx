import React from 'react';
import { ToolbarItem } from './ToolbarItem';

interface FlowchartTopToolbarProps {}
export const FlowchartTopToolbar: React.FC<FlowchartTopToolbarProps> = () => {
  return (
    <div className="top-toolbar">
      <div className="left-header">Basic</div>
      <div className="right-header">Screen with choices component</div>

      <ToolbarItem label="Blank screen" screenType="blank_screen" icon="file" />
      <div />
      {/* <ToolbarItem label="Welcome screen" border={true} screenType="welcome_screen" icon="file" /> */}
      <ToolbarItem label="Multiple choice" screenType="multiple_choice" icon="file" />
      <ToolbarItem label="Multiline text input" screenType="multiline_text" icon="file" />
      <ToolbarItem label="Slider" screenType="slider" icon="file" />
      <div />
      {/* <ToolbarItem label="Hub and spoke" screenType="hub_and" icon="file" /> */}
      <div />
      {/* <ToolbarItem label="End screen" border={true} screenType="end_screen" icon="file" /> */}
      <ToolbarItem label="Number input" screenType="number_input" icon="file" />
      <ToolbarItem label="Text input" screenType="text_input" icon="file" />
      <ToolbarItem label="Dropdown" screenType="dropdown" icon="file" />
    </div>
  );
};
