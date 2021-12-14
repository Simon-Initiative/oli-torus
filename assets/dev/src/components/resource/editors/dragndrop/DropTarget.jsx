import React, { useState } from 'react';
import { classNames } from 'utils/classNames';
export const DropTarget = ({ id, index, isLast, onDrop }) => {
    const [hovered, setHovered] = useState(false);
    const handleDragEnter = (e) => setHovered(true);
    const handleDragLeave = (e) => setHovered(false);
    const handleDrop = (e) => {
        e.preventDefault();
        setHovered(false);
        onDrop(e, index);
    };
    const handleOver = (e) => {
        e.stopPropagation();
        e.preventDefault();
    };
    return (<div key={id + '-drop'} className={classNames(['drop-target ', hovered ? 'hovered' : '', isLast ? 'is-last' : ''])} onDragEnter={handleDragEnter} onDragLeave={handleDragLeave} onDrop={handleDrop} onDragOver={handleOver}></div>);
};
//# sourceMappingURL=DropTarget.jsx.map