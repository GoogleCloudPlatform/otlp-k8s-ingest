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

@test "spans contain host.name resource attribute" {
      result=$(cat test/fixtures/spans_expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"host.name\") != null")
      assert_equal "$result" "true"
}

@test "spans contain cloud.provider resource attribute" {
      result=$(cat test/fixtures/spans_expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.provider\") != null")
      assert_equal "$result" "true"
}

@test "spans contain cloud.account.id resource attribute" {
      result=$(cat test/fixtures/spans_expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.account.id\") != null")
      assert_equal "$result" "true"
}

@test "spans contain cloud.platform resource attribute" {
      result=$(cat test/fixtures/spans_expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.platform\") != null")
      assert_equal "$result" "true"
}

@test "spans contain cloud.region resource attribute" {
      result=$(cat test/fixtures/spans_expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.region\") != null")
      assert_equal "$result" "true"
}

@test "spans contain k8s.cluster.name resource attribute" {
      result=$(cat test/fixtures/spans_expect.json | .tools/jq ".resourceSpans[].resource.attributes[]?" | .tools/jq "select(.key == \"k8s.cluster.name\") != null")
      assert_equal "$result" "true"
}

@test "logs contain host.name resource attribute" {
      result=$(cat test/fixtures/logs_expect.json | .tools/jq ".resourceLogs[].resource.attributes[]?" | .tools/jq "select(.key == \"host.name\") != null")
      assert_equal "$result" "true"
}

@test "logs contain cloud.provider resource attribute" {
      result=$(cat test/fixtures/logs_expect.json | .tools/jq ".resourceLogs[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.provider\") != null")
      assert_equal "$result" "true"
}

@test "logs contain cloud.account.id resource attribute" {
      result=$(cat test/fixtures/logs_expect.json | .tools/jq ".resourceLogs[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.account.id\") != null")
      assert_equal "$result" "true"
}

@test "logs contain cloud.platform resource attribute" {
      result=$(cat test/fixtures/logs_expect.json | .tools/jq ".resourceLogs[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.platform\") != null")
      assert_equal "$result" "true"
}

@test "logs contain cloud.region resource attribute" {
      result=$(cat test/fixtures/logs_expect.json | .tools/jq ".resourceLogs[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.region\") != null")
      assert_equal "$result" "true"
}

@test "logs contain k8s.cluster.name resource attribute" {
      result=$(cat test/fixtures/logs_expect.json | .tools/jq ".resourceLogs[].resource.attributes[]?" | .tools/jq "select(.key == \"k8s.cluster.name\") != null")
      assert_equal "$result" "true"
}

@test "metrics contain host.name resource attribute" {
      result=$(cat test/fixtures/metrics_expect.json | .tools/jq ".resourceMetrics[].resource.attributes[]?" | .tools/jq "select(.key == \"host.name\") != null")
      assert_equal "$result" "true"
}

@test "metrics contain cloud.provider resource attribute" {
      result=$(cat test/fixtures/metrics_expect.json | .tools/jq ".resourceMetrics[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.provider\") != null")
      assert_equal "$result" "true"
}

@test "metrics contain cloud.account.id resource attribute" {
      result=$(cat test/fixtures/metrics_expect.json | .tools/jq ".resourceMetrics[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.account.id\") != null")
      assert_equal "$result" "true"
}

@test "metrics contain cloud.platform resource attribute" {
      result=$(cat test/fixtures/metrics_expect.json | .tools/jq ".resourceMetrics[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.platform\") != null")
      assert_equal "$result" "true"
}

@test "metrics contain cloud.region resource attribute" {
      result=$(cat test/fixtures/metrics_expect.json | .tools/jq ".resourceMetrics[].resource.attributes[]?" | .tools/jq "select(.key == \"cloud.region\") != null")
      assert_equal "$result" "true"
}

@test "metrics contain k8s.cluster.name resource attribute" {
      result=$(cat test/fixtures/metrics_expect.json | .tools/jq ".resourceMetrics[].resource.attributes[]?" | .tools/jq "select(.key == \"k8s.cluster.name\") != null")
      assert_equal "$result" "true"
}
