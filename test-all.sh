#!/bin/bash -ex
moon fmt
moon info --target native
moon test -j 12 --target native
