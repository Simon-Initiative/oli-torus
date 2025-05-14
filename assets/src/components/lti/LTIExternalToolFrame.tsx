import React, { useEffect, useState } from 'react';

const DEFAULT_FRAME_HEIGHT = 600;

type LTIExternalToolFrameProps = {
  name: string;
  launchParams: Record<string, string>;
  resourceId: string;
  openInNewTab?: boolean;
  height?: number;
  launchOnMount?: boolean;
  onEditHeight?: (height: number | undefined) => void;
};

/**
 * LTIExternalToolFrame renders an LTI external tool link which can be launched in a new tab or in
 * an iframe.
 */
export const LTIExternalToolFrame = ({
  name,
  launchParams,
  resourceId,
  openInNewTab,
  height,
  launchOnMount,
  onEditHeight,
}: LTIExternalToolFrameProps) => {
  const frameName = `tool-content-${resourceId}`;
  const target = openInNewTab ? '_blank' : frameName;

  const [showFrame, setShowFrame] = useState(launchOnMount || false);

  const frameRef = React.useRef<HTMLIFrameElement>(null);
  const formRef = React.useRef<HTMLFormElement>(null);

  // If the launchOnMount prop is true, we submit the form immediately after the component mounts.
  // This is used in delvery mode to automatically open the tool when configured as a frame in the
  // page.
  useEffect(() => {
    if (launchOnMount) {
      if (formRef.current) {
        console.log('Submitting form:', formRef.current);
        formRef.current.submit();
      }
    }
  }, []);

  // Reset the iframe any time the openInNewTab setting changes
  useEffect(() => {
    if (!launchOnMount) {
      setShowFrame(false);
    }
  }, [openInNewTab]);

  const { editingFrameHeight, setEditingFrameHeight } = useHeightAdjuster(frameRef, onEditHeight);

  return (
    <div className="w-full h-full">
      <form
        ref={formRef}
        action={launchParams.login_url}
        className="hide"
        method="POST"
        target={target}
      >
        {Object.keys(launchParams)
          .filter((param) => param != 'login_url')
          .map((param) => (
            <input
              key={param}
              type="hidden"
              name={param}
              id={param}
              value={launchParams[param]}
            ></input>
          ))}

        {!launchOnMount && (
          <div className="flex flex-row">
            <button
              className="w-full shadow-lg px-4 py-3 mb-4 bg-white rounded-lg border-2 border-gray-100 text-left text-primary font-semibold hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              onClick={openInNewTab ? undefined : () => setShowFrame(true)}
              type="submit"
            >
              {name}
            </button>
          </div>
        )}
      </form>
      {showFrame && (
        <>
          <iframe
            ref={frameRef}
            style={{
              height: editingFrameHeight || height || DEFAULT_FRAME_HEIGHT,
              pointerEvents: editingFrameHeight ? 'none' : 'auto',
            }}
            src="about:blank"
            name={frameName}
            className="tool_launch w-full h-full"
            allowFullScreen={true}
            tabIndex={0}
            title="Tool Content"
            allow="geolocation *; microphone *; camera *; midi *; encrypted-media *; autoplay *"
            data-lti-launch="true"
          ></iframe>
          <HeightAdjustmentHandle
            height={height}
            editingFrameHeight={editingFrameHeight}
            setEditingFrameHeight={setEditingFrameHeight}
            onEditHeight={onEditHeight}
          />
        </>
      )}
    </div>
  );
};

type HeightAdjustmentHandleProps = {
  height: number | undefined;
  editingFrameHeight: number | null;
  setEditingFrameHeight: (height: number | null) => void;
  onEditHeight?: (height: number | undefined) => void;
};

const HeightAdjustmentHandle = ({
  height,
  editingFrameHeight,
  setEditingFrameHeight,
  onEditHeight,
}: HeightAdjustmentHandleProps) => {
  if (!onEditHeight) return null;

  return (
    <div
      className="flex flex-row justify-center w-full h-4 cursor-ns-resize border-t-2 border-transparent hover:border-gray-200 active:border-primary text-gray-200 active:text-primary select-none"
      onMouseDown={() => setEditingFrameHeight(height || DEFAULT_FRAME_HEIGHT)}
      onDoubleClick={() => onEditHeight?.(undefined)}
    >
      {editingFrameHeight ? (
        <span className="text-xs">{Math.floor(editingFrameHeight)}px</span>
      ) : (
        <i className="hidden hover:flex fa-solid fa-grip-lines"></i>
      )}
    </div>
  );
};

const useHeightAdjuster = (
  frameRef: React.RefObject<HTMLIFrameElement>,
  onEditHeight?: (height: number) => void,
) => {
  const [editingFrameHeight, setEditingFrameHeight] = useState<number | null>(null);

  useEffect(() => {
    if (editingFrameHeight) {
      const handleMouseMove = (event: MouseEvent) => {
        const newHeight = Math.min(
          Math.max(event.clientY - (frameRef.current?.getBoundingClientRect().top || 0), 100),
          window.innerHeight - 100, // Prevent the height from exceeding the window height
        );

        setEditingFrameHeight(newHeight);
      };
      const handleMouseUp = () => {
        setEditingFrameHeight(null);
        onEditHeight?.(editingFrameHeight);
        window.removeEventListener('mousemove', handleMouseMove);
        window.removeEventListener('mouseup', handleMouseUp);
      };
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleMouseUp);

      return () => {
        window.removeEventListener('mousemove', handleMouseMove);
        window.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [editingFrameHeight]);

  return { editingFrameHeight, setEditingFrameHeight };
};
