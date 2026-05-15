#!/bin/bash
/usr/bin/eww update CAL_DETAIL_READY=false
/usr/bin/eww update CAL_VIEW=detail
sleep 0.3
/usr/bin/eww update CAL_DETAIL_READY=true
