# frozen_string_literal: true

require 'test_helper'

class AssertionsTest < Minitest::Test
  def setup
    @old_client = StatsD.singleton_client
    env = StatsD::Instrument::Environment.new('STATSD_IMPLEMENTATION' => 'datadog')
    StatsD.singleton_client = StatsD::Instrument::Client.from_env(env)

    test_class = Class.new(Minitest::Test)
    test_class.send(:include, StatsD::Instrument::Assertions)
    @test_case = test_class.new('fake')
  end

  def teardown
    StatsD.singleton_client = @old_client
  end

  def test_assert_no_statsd_calls
    @test_case.assert_no_statsd_calls('counter') do
      # noop
    end

    @test_case.assert_no_statsd_calls('counter') do
      StatsD.increment('other')
    end

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_no_statsd_calls('counter') do
        StatsD.increment('counter')
      end
    end
    assert_equal(assertion.message, "No StatsD calls for metric counter expected.")

    @test_case.assert_no_statsd_calls('counter1', 'counter2') do
      # noop
    end

    @test_case.assert_no_statsd_calls('counter1', 'counter2') do
      StatsD.increment('counter')
    end

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_no_statsd_calls('counter1', 'counter2') do
        StatsD.increment('counter0')
        StatsD.increment('counter1')
        StatsD.increment('counter2')
        StatsD.increment('counter3')
      end
    end
    assert_equal(assertion.message, "No StatsD calls for metric counter1, counter2 expected.")

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_no_statsd_calls('counter0', 'counter1', 'counter2') do
        StatsD.increment('counter1')
      end
    end
    assert_equal(assertion.message, "No StatsD calls for metric counter1 expected.")

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_no_statsd_calls do
        StatsD.increment('other')
      end
    end
    assert_equal(assertion.message, "No StatsD calls for metric other expected.")

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_no_statsd_calls do
        StatsD.increment('other')
        StatsD.increment('another')
      end
    end
    assert_equal(assertion.message, "No StatsD calls for metric other, another expected.")
  end

  def test_assert_statsd
    @test_case.assert_statsd_increment('counter') do
      StatsD.increment('counter')
    end

    @test_case.assert_statsd_increment('counter') do
      StatsD.increment('counter')
      StatsD.increment('other')
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter') do
        StatsD.increment('other')
      end
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter') do
        StatsD.gauge('counter', 42)
      end
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter') do
        StatsD.increment('counter')
        StatsD.increment('counter')
      end
    end

    @test_case.assert_statsd_increment('counter', times: 2) do
      StatsD.increment('counter')
      StatsD.increment('counter')
    end

    @test_case.assert_statsd_increment('counter', times: 2, tags: ['foo:1']) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 1 })
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter', times: 2, tags: ['foo:1']) do
        StatsD.increment('counter', tags: { foo: 1 })
        StatsD.increment('counter', tags: { foo: 2 })
      end
    end

    @test_case.assert_statsd_increment('counter', sample_rate: 0.5, tags: ['a', 'b']) do
      StatsD.increment('counter', sample_rate: 0.5, tags: ['a', 'b'])
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter', sample_rate: 0.5, tags: ['a', 'b']) do
        StatsD.increment('counter', sample_rate: 0.2, tags: ['c'])
      end
    end
  end

  def test_assert_statsd_gauge_call_with_numeric_value
    @test_case.assert_statsd_gauge('gauge', 42) do
      StatsD.gauge('gauge', 42)
    end

    @test_case.assert_statsd_gauge('gauge', '42') do
      StatsD.gauge('gauge', 42)
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_gauge('gauge', 42) do
        StatsD.gauge('gauge', 45)
      end
    end

    @test_case.assert_statsd_gauge('gauge', value: 42) do
      StatsD.gauge('gauge', 42)
    end
  end

  def test_assert_statsd_set_call_with_string_value
    @test_case.assert_statsd_set('set', 12345) do
      StatsD.set('set', '12345')
    end

    @test_case.assert_statsd_set('set', '12345') do
      StatsD.set('set', '12345')
    end

    @test_case.assert_statsd_set('set', 12345) do
      StatsD.set('set', 12345)
    end

    @test_case.assert_statsd_set('set', '12345') do
      StatsD.set('set', 12345)
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_set('set', '42') do
        StatsD.set('set', 45)
      end
    end

    @test_case.assert_statsd_set('set', value: 12345) do
      StatsD.set('set', '12345')
    end

    @test_case.assert_statsd_set('set', 'wrong_value', value: 12345) do
      StatsD.set('set', '12345')
    end
  end

  def test_assert_statsd_service_check
    { ok: 0, warning: 1, critical: 2, unknown: 3 }.each do |symbol, integer|
      # symbol assertion works with symbol call
      @test_case.assert_statsd_service_check('my_service', symbol) do
        StatsD.service_check('my_service', symbol)
      end

      # integer assertion works with integer call
      @test_case.assert_statsd_service_check('my_service', integer) do
        StatsD.service_check('my_service', integer)
      end

      # symbol assertion works with integer call
      @test_case.assert_statsd_service_check('my_service', symbol) do
        StatsD.service_check('my_service', integer)
      end

      # integer assertion works with symbol call
      @test_case.assert_statsd_service_check('my_service', integer) do
        StatsD.service_check('my_service', symbol)
      end
    end

    { :critical => :ok, 2 => 0, :unknown => 0, 0 => :unknown }.each do |expected, actual|
      # differing statuses are detected
      assert_raises(Minitest::Assertion) do
        @test_case.assert_statsd_service_check('my_service', expected) do
          StatsD.service_check('my_service', actual)
        end
      end
    end

    # # FIXME: Skipping validation in assertion for now
    # [-1, 5, :invalid, 'OK'].each do |status|
    #   # asserting invalid statuses raises an error
    #   assert_raises(KeyError) do
    #     @test_case.assert_statsd_service_check('my_service', status) do
    #       flunk "should not have accepted assertion with status: #{status}"
    #     end
    #   end
    # end

    # value is ignored if not provided
    @test_case.assert_statsd_service_check('my_service') do
      StatsD.service_check('my_service', :ok)
    end

    # service must match
    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_service_check('my_service') do
        StatsD.service_check('other_service', :ok)
      end
    end

    # message is asserted if provided in assertion
    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_service_check('my_service', :ok, message: 'expected') do
        StatsD.service_check('my_service', :ok)
      end

      @test_case.assert_statsd_service_check('my_service', :ok, message: 'expected') do
        StatsD.service_check('my_service', :ok, message: 'actual')
      end
    end

    # message is ignored if not provided in assertion
    @test_case.assert_statsd_service_check('my_service', :ok) do
      StatsD.service_check('my_service', :ok, message: 'actual')
    end

    # TODO: Add tests for hostname & timestamp
  end

  def test_assert_statsd_event
    @test_case.assert_statsd_event('title', 'text') do
      StatsD.event('title', 'text')
    end

    # TODO: Add more tests for assert_statsd_event
  end

  def test_tags_will_match_subsets
    @test_case.assert_statsd_increment('counter', sample_rate: 0.5, tags: { a: 1 }) do
      StatsD.increment('counter', sample_rate: 0.5, tags: { a: 1, b: 2 })
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter', sample_rate: 0.5, tags: { a: 1, b: 3 }) do
        StatsD.increment('counter', sample_rate: 0.5, tags: { a: 1, b: 2, c: 4 })
      end
    end
  end

  def test_tags_friendly_error
    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter', tags: { class: "AnotherJob" }) do
        StatsD.increment('counter', tags: { class: "MyJob" })
      end
    end

    assert_includes(assertion.message, "Captured metrics with the same key")
    assert_includes(assertion.message, "MyJob")
  end

  def test_capture_and_assert
    datagrams = @test_case.capture_statsd_datagrams do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
    end

    @test_case.assert_statsd_increment('counter', tags: ['foo:1'], datagrams: datagrams)
    @test_case.assert_statsd_increment('counter', tags: ['foo:2'], datagrams: datagrams)
  end

  def test_capture_from_different_client
    client = StatsD::Instrument::Client.new
    @test_case.assert_statsd_increment('foo', client: client) do
      client.increment('foo')
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('foo', client: client) do
        StatsD.increment('foo')
      end
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('foo') do
        client.increment('foo')
      end
    end
  end

  def test_multiple_expectations_are_not_order_dependent
    foo_1_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:1'])
    foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
    @test_case.assert_statsd_expectations([foo_1_metric, foo_2_metric]) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
    end

    foo_1_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:1'])
    foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
    @test_case.assert_statsd_expectations([foo_2_metric, foo_1_metric]) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
    end

    foo_1_metric = StatsD::Instrument::Expectation.increment('counter', times: 2, tags: ['foo:1'])
    foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
    @test_case.assert_statsd_expectations([foo_1_metric, foo_2_metric]) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
    end

    foo_1_metric = StatsD::Instrument::Expectation.increment('counter', times: 2, tags: ['foo:1'])
    foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
    @test_case.assert_statsd_expectations([foo_2_metric, foo_1_metric]) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
    end

    foo_1_metric = StatsD::Instrument::Expectation.increment('counter', times: 2, tags: ['foo:1'])
    foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
    @test_case.assert_statsd_expectations([foo_2_metric, foo_1_metric]) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
      StatsD.increment('counter', tags: { foo: 1 })
    end
  end

  def test_assert_multiple_statsd_expectations
    assert_raises(Minitest::Assertion) do
      foo_1_metric = StatsD::Instrument::Expectation.increment('counter', times: 2, tags: ['foo:1'])
      foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
      @test_case.assert_statsd_expectations([foo_1_metric, foo_2_metric]) do
        StatsD.increment('counter', tags: { foo: 1 })
        StatsD.increment('counter', tags: { foo: 2 })
      end
    end

    assert_raises(Minitest::Assertion) do
      foo_1_metric = StatsD::Instrument::Expectation.increment('counter', times: 2, tags: ['foo:1'])
      foo_2_metric = StatsD::Instrument::Expectation.increment('counter', tags: ['foo:2'])
      @test_case.assert_statsd_expectations([foo_1_metric, foo_2_metric]) do
        StatsD.increment('counter', tags: { foo: 1 })
        StatsD.increment('counter', tags: { foo: 1 })
        StatsD.increment('counter', tags: { foo: 2 })
        StatsD.increment('counter', tags: { foo: 2 })
      end
    end

    foo_1_metric = StatsD::Instrument::Expectation.increment('counter', times: 2, tags: ['foo:1'])
    foo_2_metric = StatsD::Instrument::Expectation.increment('counter', 1, tags: ['foo:2'])
    @test_case.assert_statsd_expectations([foo_1_metric, foo_2_metric]) do
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 1 })
      StatsD.increment('counter', tags: { foo: 2 })
    end
  end

  def test_assert_statsd_increment_with_tags
    @test_case.assert_statsd_increment('counter', tags: ['a:b', 'c:d']) do
      StatsD.increment('counter', tags: { a: 'b', c: 'd' })
    end

    @test_case.assert_statsd_increment('counter', tags: { a: 'b', c: 'd' }) do
      StatsD.increment('counter', tags: ['a:b', 'c:d'])
    end
  end

  def test_nested_assertions
    @test_case.assert_statsd_increment('counter1') do
      @test_case.assert_statsd_increment('counter2') do
        StatsD.increment('counter1')
        StatsD.increment('counter2')
      end
    end

    @test_case.assert_statsd_increment('counter1') do
      StatsD.increment('counter1')
      @test_case.assert_statsd_increment('counter2') do
        StatsD.increment('counter2')
      end
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter1') do
        @test_case.assert_statsd_increment('counter2') do
          StatsD.increment('counter2')
        end
      end
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter1') do
        @test_case.assert_statsd_increment('counter2') do
          StatsD.increment('counter1')
        end
        StatsD.increment('counter2')
      end
    end
  end

  def test_assertion_block_with_expected_exceptions
    @test_case.assert_statsd_increment('expected_happened') do
      @test_case.assert_raises(RuntimeError) do
        begin
          raise "expected"
        rescue
          StatsD.increment('expected_happened')
          raise
        end
      end
    end

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter') do
        @test_case.assert_raises(RuntimeError) do
          raise "expected"
        end
      end
    end
    assert_includes(assertion.message, "No StatsD calls for metric counter of type c were made")
  end

  def test_assertion_block_with_unexpected_exceptions
    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter') do
        StatsD.increment('counter')
        raise "unexpected"
      end
    end
    assert_includes(assertion.message, "An exception occurred in the block provided to the StatsD assertion")

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_raises(RuntimeError) do
        @test_case.assert_statsd_increment('counter') do
          StatsD.increment('counter')
          raise "unexpected"
        end
      end
    end
    assert_includes(assertion.message, "An exception occurred in the block provided to the StatsD assertion")

    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_raises(RuntimeError) do
        @test_case.assert_no_statsd_calls do
          raise "unexpected"
        end
      end
    end
    assert_includes(assertion.message, "An exception occurred in the block provided to the StatsD assertion")
  end

  def test_assertion_block_with_other_assertion_failures
    # If another assertion failure happens inside the block, that failure should have priority
    assertion = assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('counter') do
        @test_case.flunk('other assertion failure')
      end
    end
    assert_equal("other assertion failure", assertion.message)
  end

  def test_assert_when_using_no_prefix
    env = StatsD::Instrument::Environment.new('STATSD_PREFIX' => nil)
    StatsD.singleton_client = StatsD::Instrument::Client.from_env(env)

    @test_case.assert_statsd_increment('incr', no_prefix: false) do
      StatsD.increment('incr')
    end

    @test_case.assert_statsd_increment('incr', no_prefix: true) do
      StatsD.increment('incr')
    end

    env = StatsD::Instrument::Environment.new('STATSD_PREFIX' => 'prefix')
    StatsD.singleton_client = StatsD::Instrument::Client.from_env(env)

    @test_case.assert_statsd_increment('incr', no_prefix: false) do
      StatsD.increment('incr')
    end

    assert_raises(Minitest::Assertion) do
      @test_case.assert_statsd_increment('incr', no_prefix: true) do
        StatsD.increment('incr')
      end
    end

    @test_case.assert_statsd_increment('prefix.incr', no_prefix: true) do
      StatsD.increment('incr')
    end

    @test_case.assert_statsd_increment('incr', no_prefix: true) do
      StatsD.increment('incr', no_prefix: true)
    end
  end
end
