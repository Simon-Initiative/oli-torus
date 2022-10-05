import React, { ReactNode, useEffect } from 'react';

/**
 * Component to implement a slide-out panel like the file-browser in OSX that opens up over the top of a modal
 * window, primarily used for selecting media via the MediaPickerPanel
 *
 * This will open an absolute-positioned div over the top of the modal, so make sure whatever holds this has
 * a position value set (bootstrap modals do by default).
 *
 */

interface Props {
  open: boolean;
  children: ReactNode;
}
export const SlideOutPanel: React.FC<Props> = ({ open, children }) => {
  const [pickerClass, setPickerClass] = React.useState('picker-panel');
  useEffect(() => {
    // Trigger an extra css class one frame later so the css transistion occurs
    setTimeout(() => {
      setPickerClass(open ? 'picker-panel open' : 'picker-panel');
    }, 50);
  }, [open]);

  if (!open) return null;

  return (
    <>
      <div className="picker-panel-shade" />
      <div className={pickerClass}>{children}</div>
    </>
  );
};
