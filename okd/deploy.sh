#!/usr/bin/env bash
ParamFile=$1
shift
Resourcefiles=$@
[ -r "$ParamFile" ] || exit 1
echo ${Resourcefiles:=*.yaml}
APP=$(sed -rn -e 's/APP=(.*)/\1/p' "$ParamFile")
ENV=$(sed -rn -e 's/ENV=(.*)/\1/p' "$ParamFile")

for file in $Resourcefiles; do
  Template="(cat header.tpl && sed -e '1s/.*/- &/i; 2,\$s/.*/  &/' $file && cat parameters.tpl) \
    | oc process -f - --param-file "$ParamFile""
  TypeName=($(eval "$Template" | jq -r '.items[] |[.kind,.metadata.name]|@tsv'))
  [ $? -eq 0 ] || continue
  type=${TypeName[0]}
  name=${TypeName[1]}
  if oc get $type $name; then
    case $type in
      DeploymentConfig|BuildConfig) 
        eval "$Template" | oc replace -f - $type $name ;;
      *)
        echo skip existing $type $name ;;
    esac
  else
    eval "$Template" | oc create -f - 
  fi
done

