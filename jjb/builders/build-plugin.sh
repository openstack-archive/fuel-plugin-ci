#!/bin/bash
set -ex

find . -name '*.erb' -print0 | xargs -0 -P1 -L1 -I '%' erb -P -x -T '-' % | ruby -c
find . -name '*.pp' -print0 | xargs -0 -P1 -L1 puppet parser validate --verbose
find . -name '*.pp' -print0 | xargs -0 -r -P1 -L1 puppet-lint \
          --fail-on-warnings \
          --with-context \
          --with-filename \
          --no-80chars-check \
          --no-variable_scope-check \
          --no-nested_classes_or_defines-check \
          --no-autoloader_layout-check \
          --no-class_inherits_from_params_class-check \
          --no-documentation-check \
          --no-arrow_alignment-check

fpb --check  ./
fpb --build  ./
