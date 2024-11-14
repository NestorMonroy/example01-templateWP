#!/bin/bash

set -e # If a subscript fails, exit with error.

# Run common scripts for all projects
if [ -f .provision/customizations/scripts-common.sh ]; then
    sh .provision/customizations/scripts-common.sh
fi

# Run project specific scripts
if [ -f .provision/customizations/scripts-project.sh ]; then
    sh .provision/customizations/scripts-project.sh
fi
