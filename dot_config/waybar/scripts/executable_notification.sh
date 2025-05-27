#!/bin/bash

count=$(swaync-client --count)

if [ "$count" -eq 0 ]; then
  echo "󰂜" # иконка без уведомлений
else
  echo "󰂞" # иконка с уведомлениями
fi
