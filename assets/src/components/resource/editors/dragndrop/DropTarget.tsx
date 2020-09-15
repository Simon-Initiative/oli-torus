import { useState } from 'react';
import { classNames } from 'utils/classNames';

interface DropTargetProps {
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number) => void;
  id: string;
  index: number;
  isLast: boolean;
}
export const DropTarget = ({ id, index, isLast, onDrop }: DropTargetProps) => {
  const [hovered, setHovered] = useState(false);

  const handleDragEnter = (e: React.DragEvent<HTMLDivElement>) => setHovered(true);
  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => setHovered(false);
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
    <div key={id + '-drop'}
      className={classNames(['drop-target ', hovered ? 'hovered' : '', isLast ? 'is-last' : ''])}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      onDragOver={handleOver}>
    </div>
  );
};
