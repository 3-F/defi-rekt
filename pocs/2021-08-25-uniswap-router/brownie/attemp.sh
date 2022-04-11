#!/bin/sh

cat /mnt/nas/FJunJie/projects/defi-incidents/PoCs/210825-router/scripts/data/bsc_router_list.txt | while read line
do
  echo $line
  /root/.virtualenvs/defi-incidents-wCEVE8z6/bin/python scripts/attempt.py $line &
done
