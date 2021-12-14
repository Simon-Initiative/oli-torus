import React, { Fragment } from 'react';
const CustomFieldTemplate = (props) => {
    return (<Fragment>
      {props.uiSchema['ui:title'] ? <h6>{props.uiSchema['ui:title']}</h6> : null}
      <div className="row">
        {props.description}
        {props.properties.map((element) => (<div key={element.content.key} className={`${element.content.props.uiSchema.classNames || 'col-12'} inner`}>
            {element.content}
          </div>))}
      </div>
    </Fragment>);
};
export default CustomFieldTemplate;
//# sourceMappingURL=CustomFieldTemplate.jsx.map