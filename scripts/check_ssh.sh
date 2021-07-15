#!/bin/bash
#!/bin/bash
CMD=$1
for h in master{01..03} node{01,02}
do
  echo "--------------------HostName: $h Check-----------------------------"
  ssh $h $CMD
  echo ""
done
