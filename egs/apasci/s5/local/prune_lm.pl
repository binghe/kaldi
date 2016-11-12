#!/usr/bin/env perl
use warnings; #sed replacement for -w perl parameter

# Copyright 2016  University of Bologna, Italy (Author: Chun Tian)

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

use strict;

while (<>) {
    tr/A-Z/a-z/; # convert to lowercase
    s/#0/_0/g;   # remove special #0
    s/\xC0/a'/g; # was: A'
    s/\xC8/e'/g; # was: E'
    s/\xD2/o'/g; # was: O'
    s/\xD9/u'/g; # was: U'
    s/\xE0/a'/g;
    s/\xE8/e'/g;
    s/\xF2/o'/g;
    s/\xF9/u'/g;
    # s/[^[:ascii:]]/X/g;
    print;
}
