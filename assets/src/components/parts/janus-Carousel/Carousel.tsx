/* eslint-disable react/prop-types */
import React, { createRef, CSSProperties, useEffect, useState } from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';

// TODO: fix typing
const Carousel: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [imagesLoaded, setImagesLoaded] = useState(false);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [viewedSlides, setViewedSlides] = useState<any[]>([]);
  const [captionRefs, setCaptionRefs] = useState<any[]>([]);
  const id: string = props.id;
  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  const {
    x,
    y,
    z,
    width,
    height,
    cssClasses = '',
    fontSize = 16,
    showOnAnswersReport = false,
    requireManualGrading = false,
    mode = 'Student',
    images = [],
    customCss = '',
    zoom = false,
  } = model;

  const MAGIC_NUMBER = 64;
  const PAGINATION_HEIGHT = 32;
  const styles: CSSProperties = {
    position: 'absolute',
    top: `${y}px`,
    left: `${x}px`,
    width: `${width}px`,
    height: `${height}px`,
    fontSize: `${fontSize}px`,
    zIndex: z,
    overflow: 'hidden',
    display: 'flex',
  };
  const imgStyles: CSSProperties = {
    maxWidth: `calc(${width}px - ${MAGIC_NUMBER}px)`,
    maxHeight: imagesLoaded
      ? `calc(${height}px - ${captionRefs[currentSlide]?.current?.clientHeight}px - ${PAGINATION_HEIGHT}px)`
      : `calc(${height} - ${MAGIC_NUMBER}px)`,
  };

  useEffect(() => {
    // when images[] load, refs are set on captions in order to calc() max-height for each image later
    if (images && images.length > 0) {
      setCaptionRefs((captionRefs) =>
        Array(images.length)
          .fill(images.length)
          .map((_, i) => captionRefs[i] || createRef()),
      );
    }
  }, [images]);

  const handleSlideChange = (currentSlide: any) => {
    setViewedSlides((viewedSlides) => [...viewedSlides, currentSlide]);
    setCurrentSlide(currentSlide);
  };

  return (
    <div
      data-janus-type={props.type}
      id={id}
      className={`janus-image-carousel ${cssClasses}`}
      style={styles}
    >
      {customCss && (
        <style type="text/css" style={{ display: 'none' }}>
          {customCss}
        </style>
      )}
      {images.length > 0 && (
        <Swiper
          slidesPerView={1}
          loop
          navigation
          zoom={zoom ? { maxRatio: 3 } : false}
          keyboard={{ enabled: true }}
          pagination={{ clickable: true }}
          onSwiper={(swiper) => {
            setCurrentSlide(swiper.realIndex);
          }}
          onSlideChange={(swiper) => {
            handleSlideChange(swiper.realIndex);
          }}
          onImagesReady={() => {
            setImagesLoaded(true);
          }}
        >
          {images.map((image: any, index: number) => (
            <SwiperSlide key={index} zoom={zoom}>
              <figure className="swiper-zoom-container">
                <img style={imgStyles} src={image.url} alt={image.alt ? image.alt : undefined} />
                <figcaption ref={captionRefs[index]}>{image.caption}</figcaption>
              </figure>
            </SwiperSlide>
          ))}
        </Swiper>
      )}
      {images.length <= 0 && <div className="no-images">No images to display</div>}
    </div>
  );
};

export const tagName = 'janus-carousel';

export default Carousel;
