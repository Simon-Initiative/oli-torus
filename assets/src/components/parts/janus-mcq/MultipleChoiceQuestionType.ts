import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface JanusMultipleChoiceQuestionProperties
  extends JanusCustomCss,
    JanusAbsolutePositioned {
  title: string;
}

export interface JanusMultipleChoiceQuestionItemProperties extends JanusCustomCss {
  nodes: [];
  multipleSelection: boolean;
  itemId: string;
  layoutType: string;
  totalItems: number;
  groupId: string;
  selected: boolean;
  val: number;
  disabled?: boolean;
  index: number;
  overrideHeight: boolean;
  onConfigOptionClick?: any;
  configureMode?: boolean;
  verticalGap: number;
}
