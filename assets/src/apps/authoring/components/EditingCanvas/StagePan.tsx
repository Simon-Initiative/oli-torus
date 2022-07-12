import React, { useCallback, useState } from 'react';

export const StagePan: React.FC = ({ children }) => {
  const [transformation, setTransformation] = useState({
    originX: 0,
    originY: 0,
    translateX: 0,
    translateY: 0,
  });
  const [moving, setMoving] = useState(false);

  const pan = (originX: number, originY: number) => {
    const { translateX, translateY } = transformation;
    setTransformation({
      ...transformation,
      translateX: translateX + originX,
      translateY: translateY + originY,
    });
  };

  const getTranslate = useCallback(
    (translateX = 0, translateY = 0) => `translate(${translateX}px, ${translateY}px)`,
    [],
  );

  const onMove = (event: any) => {
    if (!moving) {
      return;
    }
    event.preventDefault();
    pan(event.movementX, event.movementY);
  };

  return (
    <div
      className={`aa-stage-pan`}
      style={{
        cursor: moving ? 'grabbing' : 'default',
        transform: getTranslate(transformation.translateX, transformation.translateY),
      }}
      onMouseMove={onMove}
      onMouseDown={(e) => {
        /*  console.log('pan event', e); */
        const clickTarget = e.target;
        if (
          (clickTarget as HTMLElement).classList.contains('aa-stage-pan') ||
          (clickTarget as HTMLElement).classList.contains('activity-content')
        ) {
          setMoving(true);
        }
      }}
      onMouseUp={() => setMoving(false)}
      onMouseLeave={() => setMoving(false)}
    >
      {children}
    </div>
  );
};

export default StagePan;
