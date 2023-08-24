#!/bin/bash

set -e

help ()
{
  echo "package-charts - a script that packages a chart and updates the repository's chart index"
  echo "USAGE"
  echo -e "\t -o|--output REQUIRED <the relative path to where chart packages are stored>"
  echo -e "\t -b|--branch REQUIRED <the branch to check changes against>"
  echo -e "\t --dry-run OPTIONAL <checks if chart version has been packaged BUT does not package the chart if a version does not already exist>"
  echo -e "\nExample:\n\t package-charts -c=./charts/fc-helm-dependencies -o=./releases"
}

for arg in "$@"
do
  case $arg in
      --dry-run)
      DRY_RUN="true"
      shift
      ;;
      -o=*|--output=*)
      RELEASE_LOCATION="${arg#*=}"
      shift
      ;;
      -b=*|--branch=*)
      BRANCH="${arg#*=}"
      shift
      ;;
      -h|--help)
      help
      exit 0
      shift
      ;;
  esac
done

if [ -z $RELEASE_LOCATION ] || [ -z $BRANCH ] ; then
  echo "please provide the correct number of arguments to this application."
  help
  exit 1
fi

CHARTS=()
for DIR in ./charts/*/; do
  if ! git diff-index --quiet $BRANCH -- $DIR || [ -n "$(git ls-files -o -- $DIR)" ]; then
    CHARTS+=($DIR)
  fi
done

if [ ${#CHARTS[@]} -eq 0 ]; then
  echo "no changes have been found - no need to check/package charts, exiting gracefully."
  exit 0
fi

for CHART in "${CHARTS[@]}"; do
  echo "detected changes in $CHART..."

  VERSION=$(yq eval .version "$CHART/Chart.yaml")
  NAME=$(yq eval .name "$CHART/Chart.yaml")

  echo "found chart in $CHART - $NAME $VERSION."
  echo "scanning for packaged releases with the version '$VERSION'..."

  if find ./releases/$NAME-$VERSION.tgz 2>/dev/null; then
    echo "ERROR: a release for $NAME under version $VERSION has already been packaged."
    echo "please bump the version number of the chart within $CHART/Chart.yaml."
    exit 1
  fi

  if [ ! -z $DRY_RUN ]; then
    echo "DRY_RUN: would have packaged helm chart $NAME with version $VERSION"
    continue
  fi

  helm package $CHART -d $RELEASE_LOCATION --version $VERSION
done

if [ -z $DRY_RUN ]; then
  helm repo index ./
fi
