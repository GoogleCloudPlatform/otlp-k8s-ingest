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

@test "contains host.name resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"host.name\") != null")
      assert_equal "$result" "true"
}

@test "contains cloud.provider resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.provider\") != null")
      assert_equal "$result" "true"
}

@test "contains cloud.account.id resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.account.id\") != null")
      assert_equal "$result" "true"
}

@test "contains cloud.platform resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.platform\") != null")
      assert_equal "$result" "true"
}

@test "contains cloud.region resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.region\") != null")
      assert_equal "$result" "true"
}

@test "contains k8s.cluster.name resource attribute" {
      result=$(cat test/fixtures/expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"k8s.cluster.name\") != null")
      assert_equal "$result" "true"
}
