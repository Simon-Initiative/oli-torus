import React, { useEffect, useRef, useState } from 'react';
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
          viewBox="0 0 14 14"
          width="24"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path d="M4.646 4.646a.5.5 0 01.708 0L8 7.293l2.646-2.647a.5.5 0 01.708.708L8.707 8l2.647 2.646a.5.5 0 01-.708.708L8 8.707l-2.646 2.647a.5.5 0 01-.708-.708L7.293 8 4.646 5.354a.5.5 0 010-.708z" />
        </svg>
      </button>
      <div>
        {/* TODO: Convert to ENUM */}
        {title === 'Screens' && <ScreensIcon />}
        {title === 'Adaptivity' && <AdaptivityIcon />}
        {title === 'Inspector' && <InspectorIcon />}
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
      <ol className="list-group list-group-flush">
        {sequence?.map((s: any, i: number) => {
          return (
            <li
              key={i}
              className={`list-group-item pl-5 py-1 list-group-item-action${
                selected?.id === s.sequenceId ? ' active' : ''
              }`}
            >
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
  const [expandedRules, setExpandedRules]: any = useState({});

  const triggerAction = (e: any) => {
    e.preventDefault();
    console.log('🚀 todo: triggerAction');
  };

  return (
    <div className="adaptivity">
      <div className="accordion">
        {/* TODO: logic to switch correct / incorrect */}
        <div className="card correct">
          <div className="card-header p-2" id={`heading${1}`}>
            <h2 className="mb-0">
              <button
                className="btn btn-link btn-block text-left"
                type="button"
                data-toggle="collapse"
                data-target={`#collapse${1}`}
                aria-expanded={expandedRules[`rule-${1}`]}
                aria-controls={`collapse${1}`}
                onClick={(e) =>
                  setExpandedRules({
                    ...expandedRules,
                    [`rule-${1}`]: !expandedRules[`rule-${1}`],
                  })
                }
              >
                <span
                  className={`chevron-arrow mr-2${expandedRules[`rule-${1}`] ? ' rotate' : ''}`}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="16"
                    height="16"
                    fill="currentColor"
                  >
                    <path
                      fillRule="evenodd"
                      d="M4.646 1.646a.5.5 0 01.708 0l6 6a.5.5 0 010 .708l-6 6a.5.5 0 01-.708-.708L10.293 8 4.646 2.354a.5.5 0 010-.708z"
                    />
                  </svg>
                </span>
                Correct State
              </button>
            </h2>
          </div>
          <div id={`collapse${1}`} className="collapse" aria-labelledby={`heading${1}`}>
            <div className="mt-2 pt-2 px-3 font-weight-bold text-uppercase">Conditions</div>
            <div className="card-body pt-2">
              <ul className="list-group">
                <li className="list-group-item">An item</li>
                <li className="list-group-item">A second item</li>
              </ul>
            </div>
            <div className="d-flex justify-content-between align-items-center px-3 font-weight-bold text-uppercase">
              Actions{' '}
              <button
                onClick={(e) => triggerAction(e)}
                type="button"
                className="btn btn-sm btn-outline-primary d-flex px-1"
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor">
                  <path d="M11.596 8.697l-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 010 1.393z" />
                </svg>
              </button>
            </div>
            <div className="card-body pt-2">
              <ul className="list-group">
                <li className="list-group-item">An item</li>
                <li className="list-group-item">A second item</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// Inspector Placeholder
const Inspector: React.FC<any> = () => {
  return <div className={`preview-tools-view`}>Coming Soon</div>;
};

// Reusable Icons
const ScreensIcon = () => (
  <svg
    className="dock__icon"
    fill={
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? '#ffffff'
        : '#000000'
    }
    height="24"
    viewBox="0 0 18 18"
    width="24"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path d="M0 4s0-2 2-2h12s2 0 2 2v6s0 2-2 2h-4c0 .667.083 1.167.25 1.5H11a.5.5 0 010 1H5a.5.5 0 010-1h.75c.167-.333.25-.833.25-1.5H2s-2 0-2-2V4zm1.398-.855a.758.758 0 00-.254.302A1.46 1.46 0 001 4.01V10c0 .325.078.502.145.602.07.105.17.188.302.254a1.464 1.464 0 00.538.143L2.01 11H14c.325 0 .502-.078.602-.145a.758.758 0 00.254-.302 1.464 1.464 0 00.143-.538L15 9.99V4c0-.325-.078-.502-.145-.602a.757.757 0 00-.302-.254A1.46 1.46 0 0013.99 3H2c-.325 0-.502.078-.602.145z" />
  </svg>
);

const AdaptivityIcon = () => (
  <svg
    className="dock__icon"
    fill={
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? '#ffffff'
        : '#000000'
    }
    height="24"
    viewBox="0 0 18 18"
    width="24"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      fillRule="evenodd"
      d="M6 3.5A1.5 1.5 0 017.5 2h1A1.5 1.5 0 0110 3.5v1A1.5 1.5 0 018.5 6v1H14a.5.5 0 01.5.5v1a.5.5 0 01-1 0V8h-5v.5a.5.5 0 01-1 0V8h-5v.5a.5.5 0 01-1 0v-1A.5.5 0 012 7h5.5V6A1.5 1.5 0 016 4.5v-1zM8.5 5a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1zM0 11.5A1.5 1.5 0 011.5 10h1A1.5 1.5 0 014 11.5v1A1.5 1.5 0 012.5 14h-1A1.5 1.5 0 010 12.5v-1zm1.5-.5a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1zm4.5.5A1.5 1.5 0 017.5 10h1a1.5 1.5 0 011.5 1.5v1A1.5 1.5 0 018.5 14h-1A1.5 1.5 0 016 12.5v-1zm1.5-.5a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1zm4.5.5a1.5 1.5 0 011.5-1.5h1a1.5 1.5 0 011.5 1.5v1a1.5 1.5 0 01-1.5 1.5h-1a1.5 1.5 0 01-1.5-1.5v-1zm1.5-.5a.5.5 0 00-.5.5v1a.5.5 0 00.5.5h1a.5.5 0 00.5-.5v-1a.5.5 0 00-.5-.5h-1z"
    />
  </svg>
);

const InspectorIcon = () => (
  <svg
    className="dock__icon"
    fill={
      window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
        ? '#ffffff'
        : '#000000'
    }
    height="24"
    viewBox="0 0 18 18"
    width="24"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path d="M10.478 1.647a.5.5 0 10-.956-.294l-4 13a.5.5 0 00.956.294l4-13zM4.854 4.146a.5.5 0 010 .708L1.707 8l3.147 3.146a.5.5 0 01-.708.708l-3.5-3.5a.5.5 0 010-.708l3.5-3.5a.5.5 0 01.708 0zm6.292 0a.5.5 0 000 .708L14.293 8l-3.147 3.146a.5.5 0 00.708.708l3.5-3.5a.5.5 0 000-.708l-3.5-3.5a.5.5 0 00-.708 0z" />
  </svg>
);

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

  // Navigates to Activity
  const navigate = (activityId: any) => {
    dispatch(navigateToActivity(activityId));
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
    <div id="PreviewTools" className={`preview-tools${opened ? ' opened' : ''}`}>
      {opened && (
        <Title togglePanel={togglePanel} title={view.charAt(0).toUpperCase() + view.slice(1)} />
      )}

      <div className="pt-body">
        {!opened && (
          <div className="action-picker">
            <button
              onClick={() => displayView('screens')}
              className="mb-2"
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <ScreensIcon />
            </button>
            <button
              onClick={() => displayView('adaptivity')}
              className="mb-2"
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <AdaptivityIcon />
            </button>
            <button
              onClick={() => displayView('inspector')}
              style={{
                border: 'none',
                background: 'transparent',
              }}
            >
              <InspectorIcon />
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
