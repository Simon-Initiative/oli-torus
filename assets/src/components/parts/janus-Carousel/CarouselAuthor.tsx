import React, { CSSProperties, useEffect } from 'react';
import { A11y, Keyboard, Navigation, Pagination, Zoom } from 'swiper';
import 'swiper/css';
import 'swiper/css/navigation';
import 'swiper/css/pagination';
import 'swiper/css/scrollbar';
import 'swiper/css/zoom';
import { Swiper, SwiperSlide } from 'swiper/react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import './Carousel.css';
import { CarouselModel } from './schema';

const CarouselAuthor: React.FC<AuthorPartComponentProps<CarouselModel>> = (props) => {
  const { model } = props;
  const { z = 0, width, height, fontSize = 16, images, zoom: carouselZoom } = model;
  const styles: CSSProperties = {
    fontSize: `${fontSize}px`,
    zIndex: z,
    overflow: 'hidden',
    display: 'flex',
  };
  const MAGIC_NUMBER = 75;
  const imgStyles: CSSProperties = {
    maxWidth: `calc(${width}px - ${MAGIC_NUMBER}px)`,
    maxHeight: `calc(${height} - ${MAGIC_NUMBER}px)`,
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({
      id: `${props.id}
    `,
    });
  }, []);

  return (
    <div data-janus-type={tagName} className={`janus-image-carousel`} style={styles}>
      {images.length > 0 && (
        <Swiper
          modules={[Navigation, Pagination, A11y, Keyboard, Zoom]}
          slidesPerView={1}
          loop={true}
          navigation={true}
          zoom={carouselZoom ? { maxRatio: 3 } : false}
          keyboard={{ enabled: true }}
          pagination={{ clickable: true }}
        >
          {images.map((image: any, index: number) => (
            <SwiperSlide key={index} zoom={true}>
              <figure className="swiper-zoom-container">
                <img style={imgStyles} src={image.url} alt={image.alt ? image.alt : undefined} />
                <figcaption>{image.caption}</figcaption>
              </figure>
            </SwiperSlide>
          ))}
        </Swiper>
      )}
      {images.length <= 0 && <div className="no-images">No images to display</div>}
    </div>
  );
};

export const tagName = 'janus-image-carousel';

export default CarouselAuthor;
