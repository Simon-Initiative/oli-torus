import React, { useState, useRef, useEffect } from 'react';
import * as Settings from 'components/editing/models/settings/Settings';
import { CUTE_OTTERS } from './Editor';
const onVisit = (href) => {
    window.open(href, '_blank');
};
const onCopy = (href) => {
    navigator.clipboard.writeText(href);
};
const toLink = (src) => 'https://www.youtube.com/embed/' + (src === '' ? CUTE_OTTERS : src);
export const YouTubeSettings = (props) => {
    // Which selection is active, URL or in course page
    const [model, setModel] = useState(props.model);
    const ref = useRef();
    useEffect(() => {
        // Inits the tooltips, since this popover rendres in a react portal
        // this was necessary
        if (ref !== null && ref.current !== null) {
            window.$('[data-toggle="tooltip"]').tooltip();
        }
    });
    const setSrc = (src) => setModel(Object.assign({}, model, { src }));
    const setAlt = (alt) => setModel(Object.assign({}, model, { alt }));
    const applyButton = (disabled) => (<button onClick={(e) => {
            e.stopPropagation();
            e.preventDefault();
            props.onEdit(model);
        }} disabled={disabled} className="btn btn-primary ml-1">
      Apply
    </button>);
    return (<div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref}>
        <div className="d-flex justify-content-between mb-2">
          <div>YouTube</div>

          <div>
            <Settings.Action icon="fab fa-youtube" tooltip="Open YouTube to Find a Video" onClick={() => onVisit('https://www.youtube.com')}/>
            <Settings.Action icon="fas fa-external-link-alt" tooltip="Open link" onClick={() => onVisit(toLink(model.src))}/>
            <Settings.Action icon="far fa-copy" tooltip="Copy link" onClick={() => onCopy(toLink(model.src))}/>
            <Settings.Action icon="fas fa-trash" tooltip="Remove YouTube Video" id="remove-button" onClick={() => props.onRemove()}/>
          </div>
        </div>

        <form className="form">
          <label>YouTube Video ID</label>
          <input type="text" value={model.src} onChange={(e) => setSrc(e.target.value)} className="form-control mr-sm-2"/>
          <div className="mb-2">
            <small>
              e.g. https://www.youtube.com/watch?v=<strong>zHIIzcWqsP0</strong>
            </small>
          </div>

          <label>Alt Text</label>
          <input type="text" value={model.alt} onChange={(e) => setAlt(e.target.value)} onKeyPress={(e) => Settings.onEnterApply(e, () => props.onEdit(model))} className="form-control mr-sm-2"/>
        </form>

        {applyButton(!props.editMode)}
      </div>
    </div>);
};
//# sourceMappingURL=Settings.jsx.map