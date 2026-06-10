import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect, useState }from 'react';
import { FlashcardsModel } from './schema';
import './Flashcard.css';

const FlashcardAuthor: React.FC<AuthorPartComponentProps<FlashcardsModel>> = (props) => {
  const { configuremode, id, onConfigure, onSaveConfigure } = props;
  const [model, setModel] = React.useState(props.model);


  return (
    <div className="flashcard-author">
      <h3>Flashcard Authoring</h3>
      {/* Authoring UI goes here */}
    </div>
  );
};