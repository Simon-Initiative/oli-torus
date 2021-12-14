import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import './ChoicesDelivery.scss';
export const ChoicesDelivery = ({ choices, selected, context, onSelect, isEvaluated, unselectedIcon, selectedIcon, }) => {
    const isSelected = (choiceId) => !!selected.find((s) => s === choiceId);
    return (<div className="choices__container" aria-label="answer choices">
      {choices.map((choice, index) => (<div key={choice.id} aria-label={`choice ${index + 1}`} onClick={() => (isEvaluated ? undefined : onSelect(choice.id))} className={`choices__choice-row ${isSelected(choice.id) ? 'selected' : ''}`}>
          <div className="choices__choice-wrapper">
            <label className="choices__choice-label" htmlFor={`choice-${index}`}>
              <div className="d-flex align-items-center">
                {isSelected(choice.id) ? selectedIcon : unselectedIcon}
                <div className="choices__choice-content">
                  <HtmlContentModelRenderer content={choice.content} context={context}/>
                </div>
              </div>
            </label>
          </div>
        </div>))}
    </div>);
};
//# sourceMappingURL=ChoicesDelivery.jsx.map