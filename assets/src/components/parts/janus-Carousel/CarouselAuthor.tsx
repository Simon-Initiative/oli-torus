import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { CarouselModel } from './schema';

const CarouselAuthor: React.FC<AuthorPartComponentProps<CarouselModel>> = (props) => {
  const { model } = props;

  const { x, y, z, width, height } = model;
  const styles: CSSProperties = {
    width,
    height,
    zIndex: z,
    backgroundColor: 'whitesmoke',
    border: '1px solid black',
    overflow: 'hidden',
    fontWeight: 'bold',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div style={styles}>
      <div className="container h-100">
        <div className="row h-50 justify-content-center align-items-center">
          <p>Carousel</p>
        </div>
        <div className="row h-50 justify-content-center align-items-center">
          <p>ID: {props.id}</p>
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-image-carousel';

export default CarouselAuthor;
