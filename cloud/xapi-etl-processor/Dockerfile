FROM public.ecr.aws/lambda/python:3.12 AS build

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_PREFER_BINARY=1

WORKDIR /tmp/work

COPY requirements.txt ./

RUN pip install --upgrade pip \
 && python -m pip install --only-binary=:all: --target /opt/package -r requirements.txt

COPY lambda_function.py /opt/package/

RUN dnf install -y zip \
 && cd /opt/package \
 && zip -r9 /tmp/xapi-etl-processor.zip .

FROM scratch AS export

COPY --from=build /tmp/xapi-etl-processor.zip /
