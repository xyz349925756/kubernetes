#!/bin/bash
for h in master{01..03} node{01,02};
do
  echo "---------------------------File: $h Send start ------------------------------" ;
  scp $1 $h:$2;
  echo -e "File	: $1 Send Successfull" ;
  echo "---------------------------File: $1  Send end ------------------------------";
done
