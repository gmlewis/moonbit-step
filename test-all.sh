#!/bin/bash -ex
moon fmt
moon info
moon test -j 12 --deny-warn
