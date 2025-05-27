#!/bin/bash

NOW=$(date '+%s')
gnome-screenshot -a -f /tmp/swappy-$NOW.png
swappy -f /tmp/swappy-$NOW.png
