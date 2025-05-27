#!/bin/bash

keyboard=$(hyprctl devices | awk '
    /Keyboard at/ { found=1; next }
    found { name=$1; found=0 }
    /main: yes/ { print name; exit }
')

hyprctl switchxkblayout "$keyboard" next
