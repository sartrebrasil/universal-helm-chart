#!/usr/bin/env sh
set -eu
helm lint .
helm template test-api . -f examples/values-api-java-spring.yaml >/dev/null
helm template test-worker . -f examples/values-node-worker.yaml >/dev/null
helm template test-cron . -f examples/values-python-cronjob.yaml >/dev/null
helm template test-job . -f examples/values-migration-job.yaml >/dev/null
