#!/bin/bash
kill $(ps aux | grep ft_ld | grep -v grep | awk '{print $2}')
gcc -shared -fPIC -o /tmp/time.so ./time.c -ldl
LD_PRELOAD=/tmp/time.so /usr/local/bin/ft_lock -d
