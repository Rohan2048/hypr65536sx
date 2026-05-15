#!/bin/bash
pactl list sinks | awk -F': ' '
/Description/ {
    desc=$2
    gsub(/^ +| +$/,"",desc)   # trim spaces
    gsub(/"/,"",desc)         # remove quotes
    printf "%s\"%s\"", sep, desc
    sep=","
}
END { print "" }' | awk '{print "["$0"]"}'
