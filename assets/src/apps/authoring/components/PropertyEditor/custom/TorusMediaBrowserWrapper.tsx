import React, { useContext } from 'react';
import { ReactReduxContext } from 'react-redux';

/**
 * In some contexts, this is instantiated inside the main adaptive authoring app with a full redux store set up. In those cases, we can
 * provide a nice torus media browser interface. In other contexts, we don't have a redux store set up, so we can't provide that and will
 * default to just a plain text input.
 *
 * This handles trying the browser first, and then defaulting to the plain text input.
 *
 * Usage:
 *   const Component = TorusMediaBrowserWrapper(SubComponent);
 *   <Component id="" label="" value="" onChange={() => {}} onBlur={() => {}} />
 *
 * Where Component is the new component that wraps SubComponent in the redux check.
 *
 */

export interface MediaBrowserProps {
  id: string;
  label: string;
  value: string;
  onChange: (url: string) => void;
  onBlur: (id: string, url: string) => void;
  onFocus?: () => void;
}

export type MediaBrowserComponent = React.FC<MediaBrowserProps>;

export const TorusMediaBrowserWrapper = (
  SubComponent: MediaBrowserComponent,
): React.FC<MediaBrowserProps> => {
  const Component: MediaBrowserComponent = (props) => {
    const reduxContext = useContext(ReactReduxContext);
    if (reduxContext) {
      return <SubComponent {...props} />;
    } else {
      return (
        <div className="mb-0 form-group">
          <label className="form-label">{props.label}</label>
          <input
            type="text"
            className="form-control"
            value={props.value}
            onChange={(event) => props.onChange(event.target.value)}
            onBlur={(event) => props.onBlur(props.id, event.target.value)}
            onFocus={() => {
              if (props.onFocus) props.onFocus();
            }}
          />
        </div>
      );
    }
  };
  Component.displayName = `TorusMediaBrowser(${SubComponent.displayName})`;
  return Component;
};
