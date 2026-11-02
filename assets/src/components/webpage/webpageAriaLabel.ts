import * as ContentModel from 'data/content/model/elements/types';

// Keep in sync with @default_iframe_aria_label in lib/oli/rendering/content/html.ex
export const DEFAULT_WEBPAGE_ARIA_LABEL =
  'Embedded webpage that contains additional learning content';

export const webpageAriaLabel = (webpage: ContentModel.Webpage): string =>
  (typeof webpage.title === 'string' && webpage.title.trim()) || DEFAULT_WEBPAGE_ARIA_LABEL;
