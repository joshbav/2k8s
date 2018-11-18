#!/bin/bash
echo
echo Making auto commit to  github.com/joshbav/2k8s
echo
# All files to automatically be added
git add *
git config user.name “joshbav”
git config --global user.email spam@nowhere.com
git commit -m "scripted commit $(date +%a-%b-%Y-%I-%M-%S)"
git push -u origin master
