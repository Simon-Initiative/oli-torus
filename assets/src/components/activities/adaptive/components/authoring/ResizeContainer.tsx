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
        className={selected ? 'react-draggable selected' : 'react-draggable'}
        style={{
          ...style,
          width: size?.width,
          height: size?.height,
          maxWidth: typeof size?.width === 'string' ? size.width : undefined,
          transform,
          boxSizing: 'border-box',
        }}
      >
        {children}
      </div>
    );
  } else {
    return (
      <Rnd className={selected ? 'selected' : ''} style={style} position={position} {...rndProps}>
        {children}
      </Rnd>
    );
  }
};
