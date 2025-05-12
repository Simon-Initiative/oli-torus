import React, { useEffect, useState } from 'react';

type LTIExternalToolFrameProps = {
  name: string;
  launchParams: Record<string, string>;
  resourceId: string;
  openInNewTab?: boolean;
};

/**
 * LTIExternalToolFrame renders an LTI external tool link which can be launched in a new tab or in an iframe.
 */
export const LTIExternalToolFrame = ({
  name,
  launchParams,
  resourceId,
  openInNewTab,
}: LTIExternalToolFrameProps) => {
  const frameName = `tool-content-${resourceId}`;
  const target = openInNewTab ? '_blank' : frameName;

  const [showFrame, setShowFrame] = useState(false);

  // Reset the iframe any time the openInNewTab setting changes
  useEffect(() => {
    setShowFrame(false);
  }, [openInNewTab]);

  return (
    <div className="w-full h-full">
      <form action={launchParams.login_url} className="hide" method="POST" target={target}>
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

        <div className="flex flex-row">
          <button
            className="w-full shadow-lg px-4 py-3 mb-4 bg-white rounded-lg border-2 border-gray-100 text-left text-primary font-semibold hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            onClick={openInNewTab ? undefined : () => setShowFrame(true)}
            type="submit"
          >
            {name}
          </button>
        </div>
      </form>
      {showFrame && (
        <iframe
          style={{ height: 600 }}
          src="about:blank"
          name={frameName}
          className="tool_launch w-full h-full"
          allowFullScreen={true}
          tabIndex={0}
          title="Tool Content"
          allow="geolocation *; microphone *; camera *; midi *; encrypted-media *; autoplay *"
          data-lti-launch="true"
        ></iframe>
      )}
    </div>
  );
};
