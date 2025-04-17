import React from 'react';
import { ToolbarItem } from './ToolbarItem';

interface FlowchartTopToolbarProps {}
export const FlowchartTopToolbar: React.FC<FlowchartTopToolbarProps> = () => {
  return (
    <div className="top-toolbar">
      <div className="left-header">Static Screens</div>
      <div className="right-header">Interactive Screens</div>

      <ToolbarItem label="Instructional screen" screenType="blank_screen" />

      {/* <ToolbarItem label="Welcome screen" border={true} screenType="welcome_screen"  /> */}
      <ToolbarItem label="Multiple choice" screenType="multiple_choice" />
      <ToolbarItem label="Multiline text input" screenType="multiline_text" />
      <ToolbarItem label="Slider" screenType="slider" />

      <ToolbarItem label="Text Slider" screenType="text_slider" />

      {/* <ToolbarItem label="End screen" border={true} screenType="end_screen"  /> */}
      <div />

      <ToolbarItem label="Hub and spoke" screenType="hub_spoke" />
      <ToolbarItem label="Number input" screenType="number_input" />
      <ToolbarItem label="Text input" screenType="text_input" />
      <ToolbarItem label="Dropdown" screenType="dropdown" />
    </div>
  );
};
