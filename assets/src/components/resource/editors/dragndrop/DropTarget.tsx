import React, { useState } from 'react';
import { classNames } from 'utils/classNames';
import styles from './DropTarget.modules.scss';

interface DropTargetProps {
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number) => void;
  id: string | 'last';
  index: number;
}
export const DropTarget = ({ id, index, onDrop }: DropTargetProps) => {
  const [hovered, setHovered] = useState(false);

  const handleDragEnter = (_e: React.DragEvent<HTMLDivElement>) => setHovered(true);
  const handleDragLeave = (_e: React.DragEvent<HTMLDivElement>) => setHovered(false);
  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setHovered(false);
    onDrop(e, index);
  };
  const handleOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.stopPropagation();
    e.preventDefault();
  };

  return (
    <div
      key={id + '-drop'}
      className={classNames(styles.dropTarget, hovered && styles.hovered)}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      onDragOver={handleOver}
    ></div>
  );
};
