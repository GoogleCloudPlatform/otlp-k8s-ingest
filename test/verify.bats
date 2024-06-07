#!/usr/bin/env bats

assert_equal() {
	if [[ $1 != "$2" ]]; then
		{
			echo
			echo "-- 💥 values are not equal 💥 --"
			echo "expected : $2"
			echo "actual   : $1"
			echo "--"
			echo
		} >&2 # output error to STDERR
		return 1
	fi
}

@test "contains cloud.provider resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.provider\") != null")
      assert_equal "$result" "true"     
}