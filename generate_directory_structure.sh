#!/bin/bash
# Generate Markdown representation of the Functional Income Statements directory
cd "Functional Income Statements" || exit
tree -tf --noreport -I '*~' --charset ascii . | sed -e 's/| \+/  /g' -e 's/[|`]-\+/  */g' -e 's:\(* \)\(\(.*/\)\([^/]\+\)\):\1[\4](\2):g' > ../directory_structure.md
cd ..
