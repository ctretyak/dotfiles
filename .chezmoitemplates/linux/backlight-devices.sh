#!/bin/bash

ls /sys/class/backlight 2>/dev/null | head -n 1 || true
