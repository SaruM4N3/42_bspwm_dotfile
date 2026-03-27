#!/bin/sh

# ft_lock is a 42 school host binary - skip color patching in junest (permission denied)
if [ -w /host/usr/share/42/ft_lock ]; then
    sed -i /host/usr/share/42/ft_lock \
        -e "s/bg=.*/bg=${sl_bg}/" \
        -e "s/fg=.*/fg=${sl_fg}/" \
        -e "s/ring=.*/ring=${sl_ring}/" \
        -e "s/wrong=.*/wrong=${sl_wrong}/" \
        -e "s/date=.*/date=${sl_date}/" \
        -e "s/verify=.*/verify=${sl_verify}/"
fi
