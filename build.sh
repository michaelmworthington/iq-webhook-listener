#!/bin/bash
docker build -t host.docker.internal:19447/michaelmworthington/webhook-test:v2.7.0 .
docker push host.docker.internal:19447/michaelmworthington/webhook-test:v2.7.0