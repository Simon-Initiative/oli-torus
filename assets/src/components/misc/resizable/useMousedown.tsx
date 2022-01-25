import React from 'react';

export const useMousedown = () => {
  const [mousedown, setMousedown] = React.useState(false);
  React.useEffect(() => {
    const upListener = () => setMousedown(false);
    const downListener = () => setMousedown(true);
    document.addEventListener('mouseup', upListener);
    document.addEventListener('mousedown', downListener);

    return () => {
      document.removeEventListener('mouseup', upListener);
      document.removeEventListener('mousedown', downListener);
    };
  }, []);

  return mousedown;
};
