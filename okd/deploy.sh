#!/usr/bin/env bash
ParamFile=$1
shift
Resourcefiles=$@
[ -r "$ParamFile" ] || exit 1
echo ${Resourcefiles:=*.yaml}

for file in $Resourcefiles; do
  Template="(cat header.tpl && sed -e '1s/.*/- &/i; 2,\$s/.*/  &/' $file && cat parameters.tpl) \
    | oc process -f - --param-file "$ParamFile""
  [ $? -eq 0 ] || continue
  eval "$Template" | oc apply -f -
done

