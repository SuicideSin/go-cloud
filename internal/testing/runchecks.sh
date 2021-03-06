#!/usr/bin/env bash
# Copyright 2018 The Go Cloud Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Runs only tests relevant to the current pull request.
# At the moment, this only gates running the Wire test suite.
# See https://github.com/google/go-cloud/issues/28 for solving the
# general case.

# https://coderwall.com/p/fkfaqq/safer-bash-scripts-with-set-euxo-pipefail
set -euxo pipefail

if [[ $# -gt 0 ]]; then
  echo "usage: runchecks.sh" 1>&2
  exit 64
fi

result=0

if [[ "$TRAVIS_OS_NAME" == "windows" && ( "$TRAVIS_EVENT_TYPE" == "push" || "$TRAVIS_EVENT_TYPE" == "pull_request" ) ]]; then
	echo "Skipping windows build for event type '$TRAVIS_EVENT_TYPE'"
	exit 0
fi

# Run Go tests for the root. Only do coverage for the Linux build
# because it is slow, and Coveralls will only save the last one anyway.
if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
  go test -race -coverpkg=./... -coverprofile=coverage.out ./... || result=1
  if [ -f coverage.out ]; then
    # Filter out test and sample packages.
    grep -v test coverage.out | grep -v samples > coverage2.out
    goveralls -coverprofile=coverage2.out -service=travis-ci
  fi
else
  go test -race ./... || result=1
fi
wire check ./... || result=1
# "wire diff" fails with exit code 1 if any diffs are detected.
wire diff ./... || (echo "FAIL: wire diff found diffs!" && result=1)

# Run Go tests for each additional module, without coverage.
for path in "./internal/contributebot" "./samples/appengine"; do
  ( cd "$path" && exec go test ./... ) || result=1
  ( cd "$path" && exec wire check ./... ) || result=1
  ( cd "$path" && exec wire diff ./... ) || (echo "FAIL: wire diff found diffs!" && result=1)
done
exit $result
