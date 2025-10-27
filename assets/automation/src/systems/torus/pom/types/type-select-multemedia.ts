export const TITLE_MODAL = ['Select Image', 'Embed audio', 'Select Video'] as const;
export const SORT_ORDER_TYPES = ['Newest', 'Oldest', 'A-Z', 'Z-A', 'Type', 'File Size'] as const;
export const MEDIA_TYPES = ['All Media', 'Images', 'Audio', 'Video'] as const;
export const SELECT_IMAGES_TABS = ['Media Library', 'External URL'] as const;
export const VIEW_MODES = ['Grid', 'List'] as const;
export const MEDIA_KIND = ['image', 'audio', 'video'] as const;

export type TitleModal = (typeof TITLE_MODAL)[number];
export type SortOrderType = (typeof SORT_ORDER_TYPES)[number];
export type MediaType = (typeof MEDIA_TYPES)[number];
export type SelectImageTab = (typeof SELECT_IMAGES_TABS)[number];
export type ViewMode = (typeof VIEW_MODES)[number];
export type MediaKind = (typeof MEDIA_KIND)[number];
