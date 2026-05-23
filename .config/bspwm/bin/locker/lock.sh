#!/bin/bash
kill $(ps aux | grep ft_ld | grep -v grep | awk '{print $2}')
gcc -shared -fPIC -o /home/zsonie/time.so ./time.c -ldl
LD_PRELOAD=/home/zsonie/time.so /usr/share/42/ft_lock 
