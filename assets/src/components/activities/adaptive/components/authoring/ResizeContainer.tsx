import React from 'react';
import { Props, Rnd } from 'react-rnd';

interface ResizeContainerProps {
  disabled: boolean;
  selected: boolean;
}
/**
 * Wrapper for react-rnd that can either render an <RND> or a non-moveable div depending on the
 * `disabled` prop.
 */
export const ResizeContainer: React.FC<Props & ResizeContainerProps> = ({
  children,
  disabled,
  position,
  size,
  style,
  selected,
  ...rndProps
}) => {
  if (disabled) {
    const transform = `translate(${position?.x || 0}px, ${position?.y || 0}px)`;
    return (
      <div
        className={selected ? 'adaptive-static-part-shell selected' : 'adaptive-static-part-shell'}
        style={{ ...style, width: size?.width, height: size?.height, transform }}
      >
        <div className="adaptive-part-frame">
          {children}
          <div className="part-selection-outline" aria-hidden="true" />
        </div>
      </div>
    );
  } else {
    return (
      <Rnd
        className={selected ? 'adaptive-rnd selected' : 'adaptive-rnd'}
        style={{ ...style, overflow: 'visible' }}
        position={position}
        size={size}
        {...rndProps}
      >
        <div className="adaptive-part-frame">
          {children}
          <div className="part-selection-outline" aria-hidden="true" />
        </div>
      </Rnd>
    );
  }
};
