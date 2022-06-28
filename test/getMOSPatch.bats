#!/usr/bin/env bats

# BATS test file for getMOSPatch.sh script

# some debug info when fixing tests
# echo "testdir: $BATS_TEST_DIRNAME"
# echo "tempdir: $BATS_TMPDIR"
#
# Note: the patch cleanup is not working right now so testing will leave patch files behind

# setup is run before each test is executed
setup () {

  [[ -z "$mosUser" ]] && echo "ERROR: You must set mosUser to a valid userid!"
  [[ -z "$mosPass" ]] && echo "ERROR: You must set MosPass to a valid password!"
  [[ -z "$mosUser" ]] && [[ -z "$mosPass" ]] && exit 1
  [[ -z $PATCH_NUM ]] && export PATCH_NUM=31732095
  [[ ! -f "${BATS_TEST_DIRNAME}/.getMOSPatch.sh.cfg" ]] && echo "226P;Linux x86-64" > "${BATS_TEST_DIRNAME}/.getMOSPatch.sh.cfg"
  return 0   # always return 0

}

# clean up after each test
teardown () {

  if compgen -G "${BATS_TEST_DIRNAME}/p${PATCH_NUM}*.zip"; then rm -f "${BATS_TEST_DIRNAME}/p${PATCH_NUM}*.zip"; fi
  if compgen -G "${BATS_TEST_DIRNAME}/p${PATCH_NUM}*.txt"; then rm -f "${BATS_TEST_DIRNAME}/p${PATCH_NUM}*.txt"; fi
  if compgen -G "${BATS_TEST_DIRNAME}/p${PATCH_NUM}*.xml"; then rm -f "${BATS_TEST_DIRNAME}/p${PATCH_NUM}*.xml"; fi
  [[ -f "${BATS_TEST_DIRNAME}/.getMOSPatch.sh.cfg" ]] && rm -f "${BATS_TEST_DIRNAME}/.getMOSPatch.sh.cfg"
  return 0   # always return 0

}

# what script are we running in these tests
main () {
  
  bash "${BATS_TEST_DIRNAME}"/getMOSPatch.sh $1
}

# Test - help mode
@test "getMOSPatch.sh - help mode (1)" {
  run main
  echo "${output}"
  [[ "${status}" = 1 ]]
}

# Test - invalid username / password
@test "getMOSPatch.sh - invalid username / password (2)" {

  export mosUser=testuser@test.com
  export mosPass=notrealpassword
  OPTS="patch=${PATCH_NUM}"
  run main "${OPTS}"
  echo "${output}"
  [[ "${status}" = 2 ]]
}


# Test - download patch - be sure to set environment variable for username password
@test "getMOSPatch.sh - download test patch requires username and password (0)" {

  OPTS="patch=${PATCH_NUM} destination=${BATS_TEST_DIRNAME}"
  echo "command: $OPTS"
  run main "${OPTS}"
  echo "${output}"
  [[ "${status}" = 0 ]]
}

# Test - download patch with regexep - be sure to set environment variable for username password
@test "getMOSPatch.sh - download patch with regex requires username and password (0)" {

  PATCH_NUM=6880880
  REGEXP=19
  OPTS="patch=${PATCH_NUM} destination=${BATS_TEST_DIRNAME} regexp=${REGEXP}"
  echo "command: $OPTS"
  run main "${OPTS}"
  echo "${output}"
  [[ "${status}" = 0 ]]
}


# Test - download patch with regexep,readme, and xml - be sure to set environment variable for username password
@test "getMOSPatch.sh - download patch with regex, readme, and xml requires username and password (0)" {

  PATCH_NUM=6880880
  REGEXP=19
  OPTS="patch=${PATCH_NUM} destination=${BATS_TEST_DIRNAME} regexp=${REGEXP} readme=yes xml=yes"
  echo "command: $OPTS"
  run main "${OPTS}"
  echo "${output}"
  [[ "${status}" = 0 ]]
}
