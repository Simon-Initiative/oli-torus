export const titleModal = ['Select Image', 'Embed audio', 'Select Video'] as const;
export const sortOrderTypes = ['Newest', 'Oldest', 'A-Z', 'Z-A', 'Type', 'File Size'] as const;
export const mediaTypes = ['All Media', 'Images', 'Audio', 'Video'] as const;
export const selectImageTabs = ['Media Library', 'External URL'] as const;
export const viewModes = ['Grid', 'List'] as const;
export const MEDIA_KIND = { image: 'image', audio: 'audio', video: 'video' } as const;

export type TitleModal = (typeof titleModal)[number];
export type SortOrderType = (typeof sortOrderTypes)[number];
export type MediaType = (typeof mediaTypes)[number];
export type SelectImageTab = (typeof selectImageTabs)[number];
export type ViewMode = (typeof viewModes)[number];
export type MediaKind = keyof typeof MEDIA_KIND;
