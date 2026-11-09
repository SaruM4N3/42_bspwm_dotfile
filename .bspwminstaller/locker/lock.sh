#!/bin/bash
kill $(ps aux | grep ft_ld | grep -v grep | awk '{print $2}')
gcc -shared -fPIC -o /tmp/lockbg.so ./lockbg.c -ldl
LD_PRELOAD=/tmp/lockbg.so /usr/local/bin/ft_lock -d
