#!/bin/bash
i=0
while true; do
  let i=i+1
  # No namespace case
  echo "example:$i|g" | nc -w 1 -u 0.0.0.0 8125
  echo "example:-$i|g" | nc -w 1 -u 0.0.0.0 8125
  # # Base case  
  echo "example.counter:1|c" | nc -w 1 -u 0.0.0.0 
  echo "example.counter:$i|c" | nc -w 1 -u 0.0.0.0 8125
  echo "example.counter_tens:10|c" | nc -w 1 -u 0.0.0.0 8125
  echo "example.counter_random:$RANDOM|c" | nc -w 1 -u 0.0.0.0 8125
  echo "example.timer:$RANDOM|ms" | nc -w 1 -u 0.0.0.0 8125
  echo "example.gauge:-$i|g" | nc -w 1 -u 0.0.0.0 8125
  # # # Base case with instance
  echo "example.counter,instance=1:1|c" | nc -w 1 -u 0.0.0.0 8125
  echo "example.gauge,instance=0:+$i|g" | nc -w 1 -u 0.0.0.0 8125
  echo "example.gauge,instance=bazinga:-$i|g" | nc -w 1 -u 0.0.0.0 8125
  # # Base case with tags
  echo "example.gauge,x=10:-$i|g" | nc -w 1 -u 0.0.0.0 8125
  echo "example.counter,tagY=Y,tagX=X:1|c" | nc -w 1 -u 0.0.0.0 8125
  echo "example.gauge,x=10,y=20:-$i|g" | nc -w 1 -u 0.0.0.0 8125
  # # # Base case with tags and instance
  echo "example.counter,tagY=Y,tagX=X,instance=1:1|c" | nc -w 1 -u 0.0.0.0 8125
  echo "example.gauge,i=30,b=10,instance=1:$RANDOM|g" | nc -w 1 -u 0.0.0.0 8125
  echo "example.gauge,x=10,y=20,instance=bazinga:-$i|g" | nc -w 1 -u 0.0.0.0 8125
  # # # Invalid characters case
  echo "example.g a-u/g e,instance=bazinga:-$i|g" | nc -w 1 -u 0.0.0.0 8125  
  # # # Invalid case -- too long for buffer
  echo "example.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:1|c" | nc -w 1 -u 0.0.0.0 8125
  sleep 1
done