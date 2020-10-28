# +NOTE: optionally specify 
#    ```docker build --build-arg ALT_DOCKER_REGISTRY=host.docker.internal:19443 --build-arg ALT_PYPI_REGISTRY=http://host.docker.internal:8083/nexus/repository/pypi-python.org-proxy/simple -t iq-success-metrics:latest .``` 
#    to download images from a location other than docker hub



#ARG ALT_DOCKER_REGISTRY=docker.io
ARG ALT_DOCKER_REGISTRY=host.docker.internal:19443

FROM $ALT_DOCKER_REGISTRY/almir/webhook:2.7.0

RUN     apk update && apk upgrade && apk add openjdk8-jre curl jq

COPY 	hooks/quay.json \
        hooks/jenkins.json \
        hooks/nxrm-prime.json \
        hooks/dockerHub-scan.json \
        hooks/iq-consume.json \
        hooks/nxrm-consume.json \
        hooks/post-iq-scan-to-deptrack.json \
        hooks/test.json \
        /etc/webhook/

COPY	scripts/quayScan.sh \
        scripts/jenkins.sh \
        scripts/nxrm-prime.sh \
        scripts/dockerHub-scan.sh \
        scripts/iq-consume.sh \
        scripts/nxrm-consume.sh \
        scripts/post-iq-scan-to-deptrack.sh \
        scripts/test.sh \
        /etc/webhook/

#COPY	nexus-iq-cli-1.60.0-02.jar /etc/webhook/nexus-iq-cli.jar
