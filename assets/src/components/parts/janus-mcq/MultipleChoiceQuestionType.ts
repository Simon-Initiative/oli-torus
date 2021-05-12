 import { JanusAbsolutePositioned, JanusCustomCssActivity } from "../types/parts";

export interface JanusMultipleChoiceQuestionProperties
    extends JanusCustomCssActivity,
        JanusAbsolutePositioned {
    title: string;
}

export interface JanusMultipleChoiceQuestionItemProperties
    extends JanusCustomCssActivity {
    nodes: [];
    multipleSelection: boolean;
    itemId: string;
    layoutType: string;
    totalItems: number;
    groupId: string;
    selected: boolean;
    val: number;
    disabled?: boolean;
}