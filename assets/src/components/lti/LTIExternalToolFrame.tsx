import React from 'react';

type LTIExternalToolFrameProps = {
  launchParams: Record<string, string>;
  resourceId: string;
};

export const LTIExternalToolFrame = ({ launchParams, resourceId }: LTIExternalToolFrameProps) => {
  return (
    <div className="mt-3" style={{ height: 600 }}>
      <form
        action={launchParams.login_url}
        className="hide"
        method="POST"
        target={`tool-content-${resourceId}`}
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

        <div style={{ marginBottom: 20 }}>
          <button className="btn btn-primary" type="submit">
            Launch LTI 1.3 Tool
          </button>
        </div>
      </form>
      <iframe
        src="about:blank"
        name={`tool-content-${resourceId}`}
        className="tool_launch w-full h-full"
        allowFullScreen={true}
        tabIndex={0}
        title="Tool Content"
        allow="geolocation *; microphone *; camera *; midi *; encrypted-media *; autoplay *"
        data-lti-launch="true"
      ></iframe>
    </div>
  );
};
