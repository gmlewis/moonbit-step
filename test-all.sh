#!/bin/bash -ex
export NEW_MOON=1
moon fmt
moon info --target native
moon test --target native
