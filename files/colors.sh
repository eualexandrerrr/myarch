#!/usr/bin/env bash

RST=$(tput sgr0)                    ## reset flag
RED=$RST$(tput setaf 1)             #  red, plain
GRE=$RST$(tput setaf 2)             #  green, plain
BLU=$RST$(tput setaf 4)             #  blue, plain
CYA=$RST$(tput setaf 6)             #  cyan, plain
BLD=$(tput bold)                    ## bold flag
BLD_RED=$RST$BLD$(tput setaf 1)     #  red, bold
BLD_GRN=$RST$BLD$(tput setaf 2)     #  green, bold
BLD_BLU=$RST$BLD$(tput setaf 4)     #  blue, bold
BLD_CYA=$RST$BLD$(tput setaf 6)     #  cyan, bold
