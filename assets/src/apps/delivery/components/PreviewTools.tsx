import React, { useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectCurrentActivity } from '../store/features/activities/slice';
import { navigateToActivity } from '../store/features/groups/actions/deck';

// Title Component
interface TitleProps {
  title: string;
  togglePanel: () => void;
}
const Title: React.FC<any> = (props: TitleProps) => {
  const { title, togglePanel } = props;
  return (
    <div className="pt-header">
      <button onClick={() => togglePanel()}>
        <svg
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          height="24"
          viewBox="0 0 24 24"
          width="24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"></path>
        </svg>
      </button>
      <div>
        <svg
          className="dock__icon"
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          height="22"
          viewBox="0 0 576 512"
          width="22"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M528 0H48C21.5 0 0 21.5 0 48v320c0 26.5 21.5 48 48 48h192l-16 48h-72c-13.3 0-24 10.7-24 24s10.7 24 24 24h272c13.3 0 24-10.7 24-24s-10.7-24-24-24h-72l-16-48h192c26.5 0 48-21.5 48-48V48c0-26.5-21.5-48-48-48zm-16 352H64V64h448v288z" />
        </svg>
        <div className="pt-title">{title}</div>
      </div>
    </div>
  );
};

// Screen Selector View
interface ScreenSelectorProps {
  sequence: any;
  navigate: any;
  selected: any;
}
const ScreenSelector: React.FC<ScreenSelectorProps> = ({
  sequence,
  navigate,
  selected,
}: ScreenSelectorProps) => {
  return (
    <div className={`preview-tools-view`}>
      <ol>
        {sequence?.map((s: any, i: number) => {
          return (
            <li key={i}>
              <a
                href=""
                className={selected?.id === s.sequenceId ? 'selected' : ''}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(s.sequenceId);
                }}
              >
                {s.sequenceName}
              </a>
            </li>
          );
        })}
      </ol>
    </div>
  );
};

// Adaptivity Placeholder
const Adaptivity: React.FC<any> = () => {
  return <div className={`preview-tools-view`}>Comming Soon</div>;
};

// Inspector Placeholder
const Inspector: React.FC<any> = () => {
  return <div className={`preview-tools-view`}>Comming Soon</div>;
};

// Primary Preview Tools component
interface PreviewToolsProps {
  model: any;
}
const PreviewTools: React.FC<any> = (props: PreviewToolsProps): any | false => {
  const [opened, setOpened] = useState<boolean>(false);
  const [view, setView] = useState<string>('screens');
  const selected = useSelector(selectCurrentActivity);
  const dispatch = useDispatch();
  const sequence = props.model[0].children
    ?.filter((child: any) => !child.custom.isLayer && !child.custom.isBank)
    .map((s: any) => {
      return { ...s.custom };
    });

  // Navigates to Ensemble
  const navigate = (ensembleId: any) => {
    dispatch(navigateToActivity(ensembleId));
  };

  // Toggle the menu open/closed
  const togglePanel = () => {
    setOpened(!opened);
  };

  // Fires when selecting a tool to open
  const displayView = (view: any) => {
    setView(view);
    setOpened(true);
  };

  return (
    <div id="PreviewTools" className={`preview-tools ${opened && 'opened'}`}>
      {opened && (
        <Title togglePanel={togglePanel} title={view.charAt(0).toUpperCase() + view.slice(1)} />
      )}

      <div className="pt-body">
        {!opened && (
          <div className="action-picker">
            <button
              onClick={() => displayView('screens')}
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <svg
                className="dock__icon"
                fill={
                  window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
                    ? '#ffffff'
                    : '#000000'
                }
                height="22"
                viewBox="0 0 576 512"
                width="22"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path d="M528 0H48C21.5 0 0 21.5 0 48v320c0 26.5 21.5 48 48 48h192l-16 48h-72c-13.3 0-24 10.7-24 24s10.7 24 24 24h272c13.3 0 24-10.7 24-24s-10.7-24-24-24h-72l-16-48h192c26.5 0 48-21.5 48-48V48c0-26.5-21.5-48-48-48zm-16 352H64V64h448v288z" />
              </svg>
            </button>
            <button
              onClick={() => displayView('adaptivity')}
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <svg
                className="dock__icon"
                fill={
                  window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
                    ? '#ffffff'
                    : '#000000'
                }
                height="24"
                viewBox="0 0 24 24"
                width="24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path d="M18.192 7.207L19.985 9V4h-5l1.793 1.793-5.53 5.53.707-.294H4v2h8.37l.292-.294 5.53-5.53zm-3.377 6.203l-1.41 1.41 3.13 3.13-2.05 2.05h5.5v-5.5l-2.04 2.04-3.13-3.13z"></path>
              </svg>
            </button>
            <button
              onClick={() => displayView('inspector')}
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <svg
                className="dock__icon"
                fill={
                  window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
                    ? '#ffffff'
                    : '#000000'
                }
                height="24"
                viewBox="0 0 24 24"
                width="24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path d="M20 19.59V8l-6-6H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c.45 0 .85-.15 1.19-.4l-4.43-4.43c-.8.52-1.74.83-2.76.83-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5c0 1.02-.31 1.96-.83 2.75L20 19.59zM9 13c0 1.66 1.34 3 3 3s3-1.34 3-3-1.34-3-3-3-3 1.34-3 3z"></path>
              </svg>
            </button>
          </div>
        )}
        {opened && view === 'screens' && (
          <ScreenSelector sequence={sequence} navigate={navigate} selected={selected} />
        )}
        {opened && view === 'adaptivity' && <Adaptivity sequence={sequence} navigate={navigate} />}
        {opened && view === 'inspector' && <Inspector sequence={sequence} navigate={navigate} />}
      </div>
    </div>
  );
};

export default PreviewTools;
