ARG BASE_IMAGE=public.ecr.aws/lambda/python:3.11

FROM ${BASE_IMAGE} AS build

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_PREFER_BINARY=1

WORKDIR /opt

COPY requirements.txt /tmp/requirements.txt

RUN pip install --upgrade pip \
    && python -m pip install --target /opt/python -r /tmp/requirements.txt

RUN yum install -y zip

RUN cd /opt \
    && zip -r9 /tmp/xapi-etl-processor-layer.zip python

FROM scratch AS export

COPY --from=build /tmp/xapi-etl-processor-layer.zip /
