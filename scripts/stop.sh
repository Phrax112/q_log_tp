#!/bin/bash

kill -9 `ps -ef | grep 'tick.q\|r.q' | grep -v grep | awk '{print $2}'`

rm -rf /Users/gmoy/projects/qlogTP/tplogs/sym*


