import { JanusAbsolutePositioned, JanusCustomCssActivity } from '../types/parts';

export interface JanusImageProperties extends JanusCustomCssActivity, JanusAbsolutePositioned {
  src: string;
  alt?: string;
  scaleContent?: boolean;
  lockAspectRatio?: boolean;
}

export enum JanusCarouselModes {
  STUDENT = 'Student',
  CONFIG = 'Config',
}
export interface JanusCarouselProperties extends JanusCustomCssActivity, JanusAbsolutePositioned {
  title?: string;
  id: string;
  cssClasses?: string;
  fontSize?: number;
  showOnAnswersReport?: boolean;
  requireManualGrading?: boolean;
  src: string;
  mode: JanusCarouselModes;
  images: JanusImageProperties[];
  customCss?: string;
  zoom?: boolean;
}
