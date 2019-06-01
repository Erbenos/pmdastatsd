#!/bin/bash
make clean && make

make run &

# wait until program is ready to listen
# not sure how else to it now
sleep 3;

./test/data/duration.sh

pid=$(pgrep pcp-statsd.out)
kill -USR1 $pid
# I have no idea how to watch output of parallel task and block until given text is found
sleep 5
kill -INT $pid