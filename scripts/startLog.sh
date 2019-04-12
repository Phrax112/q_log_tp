#!/bin/bash

cd $LOGTP/qScripts

q tick.q sym ../tplogs -p 5010 > ../logs/tick.log 2>&1 </dev/null &
q tick/r.q :5010 :5012 -p 5011 > ../logs/rdb.log 2>&1 </dev/null &
