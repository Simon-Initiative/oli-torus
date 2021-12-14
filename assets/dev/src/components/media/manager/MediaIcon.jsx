import * as React from 'react';
import { FileIcon } from './FileIcon';
import { ImageIcon } from './ImageIcon';
import { isImage } from './utils';
const getMediaIconRenderer = (mimeType) => {
    if (isImage(mimeType)) {
        return ImageIcon;
    }
    return FileIcon;
};
/**
 * MediaIcon React Stateless MediaIcon
 */
export const MediaIcon = ({ 
// eslint-disable-next-line
className, 
// eslint-disable-next-line
filename, 
// eslint-disable-next-line
mimeType, 
// eslint-disable-next-line
url, }) => {
    // eslint-disable-next-line
    const extensionMatches = filename.match(/\.[^.]+$/);
    const extension = extensionMatches ? extensionMatches[0].substr(1, 3).toLowerCase() : '';
    const Icon = getMediaIconRenderer(mimeType);
    return (<div className={`media-icon ${className || ''}`}>
      <Icon filename={filename} extension={extension} url={url}/>
    </div>);
};
//# sourceMappingURL=MediaIcon.jsx.map