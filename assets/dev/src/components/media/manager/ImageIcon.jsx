import * as React from 'react';
/**
 * ImageIcon React Stateless Component
 */
export const ImageIcon = ({ 
// eslint-disable-next-line
className, 
// eslint-disable-next-line
url, }) => {
    return (<div className={`image-icon ${className || ''}`}>
      <img src={url}/>
    </div>);
};
//# sourceMappingURL=ImageIcon.jsx.map