#!/bin/bash

############################################################
#################### LOGGING FUNCTIONS #####################
log_error() { printf "%s - [ERROR] %s\n" "$(date)" "$1" >&2; exit 1; }
log_info() { printf "%s - [INFO] %s\n" "$(date)" "$1"; }

portForward() {
  kubectl port-forward svc/argocd-server -n argocd 8080:443 2>&1 >/dev/null &
  # kill $(lsof -t -i:8080)
}
startAppSetController() {
  make applicationset-controller
  ./dist/argocd-applicationset-controller --metrics-addr=":18081" --probe-addr=":18082" --argocd-repo-server=localhost:8081 --debug  --namespace=argocd
}

setCredentials() {
  if git config --list | grep credential ; then
    log_error "Credential Helper is already present";
  fi
  sudo git config -f "/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig" --add credential.helper osxkeychain
  cat "/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig"
}

unsetCredentials() {
  sudo git config -f "/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig" --unset credential.helper
  cat "/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig"
}

forwardRepoServer() {
  kubectl port-forward svc/argocd-repo-server 8091:8081
}

getLogsByTime() {
  cat "RAW_LOGS.txt" | grep "time_ms" | sed "s;.*0m=;;" | sort > "TIME_LOGS.txt"
}

getGitLogs() {
  cat "RAW_LOGS.txt" | grep "git" | grep "Trace" | grep "ls-files" | sed "s;.*0m=;;" | sort > "GIT_LOGS/LS_FILES.txt"
  cat "RAW_LOGS.txt" | grep "git" | grep "Trace" | grep "fetch" | sed "s;.*0m=;;" | sort > "GIT_LOGS/FETCH.txt"
  cat "RAW_LOGS.txt" | grep "git" | grep "Trace" | grep "checkout" | sed "s;.*0m=;;" | sort > "GIT_LOGS/CHECKOUT.txt"
  cat "RAW_LOGS.txt" | grep "git" | grep "Trace" | grep "clean" | sed "s;.*0m=;;" | sort > "GIT_LOGS/CLEAN.txt"
}

getUnchanged() {
  cat "RAW_LOGS.txt" | grep "unchanged Application" | sort > "GIT_LOGS/UNCHANGED.txt"
}

getGenerators() {
  cat "RAW_LOGS/RAW_LOGS_MAIN.txt" | grep JAYK | grep "GENERATED PARAMS" | sed "s;.*SECONDS:;;"
}

getLongestGenerators() {
#  GEN_TIMES="$(cat "RAW_LOGS.txt" | grep JAYK | grep "GENERATED PARAMS" | sed "s;.*SECONDS:;;" | sed "s;generator.*;;" | sed -e "s;\..*;;" | sort -V)"
  GEN_TIMES="$(getGenerators | sed "s;.*SECONDS:;;" | sed "s;generator.*;;" | awk '$1 > 60')" # Get times over 1 minute
  while IFS= read -r GEN_TIME; do
    echo "$GEN_TIME"
    cat "RAW_LOGS.txt" | grep JAYK | grep "GENERATED PARAMS" | grep "$GEN_TIME"
  done <<<"$GEN_TIMES"
}

getShortestGenerators() {
  GEN_TIMES="$(getGenerators | sed "s;.*SECONDS:;;" | sed "s;generator.*;;" | awk '$1 < 60')" # Get times under 1 minute
  while IFS= read -r GEN_TIME; do
    CURR_TIME=$(echo "$GEN_TIME" | xargs)
#    cat "RAW_LOGS.txt" | tr -d '[' | tr -d ']' | tr -d '(' | tr -d ')' | grep JAYK | grep "GENERATED PARAMS" | grep -e "$CURR_TIME"
    cat "RAW_LOGS.txt" | tr -d '[' | tr -d ']' | tr -d '(' | tr -d ')' | grep JAYK | grep "GENERATED PARAMS" | grep -e "$CURR_TIME"
  done <<<"$GEN_TIMES"
}

getGitGenerators() {
  GENERATORS="$(getGenerators | grep -e "Git:&GitGenerator" | grep -ve "Matrix:&Matrix")"
  GENERATOR_TIMES="$(echo "$GENERATORS" | sed "s;generator.*;;" | sort -V | tee GIT_GEN_TIMES.txt)"
  echo "$GENERATORS"
}

getClusterGenerators() {
  GENERATORS="$(getGenerators | grep -e "Clusters:&ClusterGenerator" | grep -ve "Matrix:&Matrix")"
  GENERATOR_TIMES="$(echo "$GENERATORS" | sed "s;generator.*;;" | sort -V | tee CLUSTER_GEN_TIMES.txt)"
  echo "$GENERATORS"
}

getMatrixGenerators(){
  GENERATORS="$(getGenerators | grep -e "Matrix:&Matrix")"
  GENERATOR_TIMES="$(echo "$GENERATORS" | sed "s;generator.*;;" | sort -V | tee MATRIX_GEN_TIMES.txt)"
  echo "$GENERATORS"
}

getMergeGenerators(){
  GENERATORS="$(getGenerators | grep -e "Merge:&Merge")"
  GENERATOR_TIMES="$(echo "$GENERATORS" | sed "s;generator.*;;" | sort -V | tee MERGE_GEN_TIMES.txt)"
  echo "$GENERATORS"
}

drillMatrixGit(){
  GENERATORS="$(cat SIMPLE_LOGS.txt | grep "JAYK-MATRIX-GEN-PARAM\|JAYK-GIT-GEN-PARAM")"
#  GENERATOR_TIMES="$(echo "$GENERATORS" | sed "s;.*:;;" | sort -V | tee MATRIX_GEN_PARAM_TIMES.txt)"
  echo "$GENERATORS"
}

case "$1" in
    "") sleep infinity; exit;;
    *) "$@"; exit;;
esac

# 1) Create issue (for identifying appsets), W/ Mock tests etc.
# 2) Identify Current Problem Appsets
# 3) Add Linting Rule Fail build for New Appsets w/ Matrices (Cert-Manager)
# 4) Wiki Page for rationale for Linting Rule
# 5)
