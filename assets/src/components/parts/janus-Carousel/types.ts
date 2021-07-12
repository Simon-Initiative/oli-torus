import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface JanusImageProperties extends JanusCustomCss, JanusAbsolutePositioned {
  src: string;
  alt?: string;
  scaleContent?: boolean;
  lockAspectRatio?: boolean;
}

export enum JanusCarouselModes {
  STUDENT = 'Student',
  CONFIG = 'Config',
}
export interface JanusCarouselProperties extends JanusCustomCss, JanusAbsolutePositioned {
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
