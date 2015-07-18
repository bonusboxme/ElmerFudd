require 'test_helper'

class CastTest < MiniTest::Unit::TestCase
  TEST_QUEUE = "test.ElmerFudd.cast"

  class TestWorker < ElmerFudd::Worker
    default_filters ElmerFudd::JsonFilter

    handle_cast(Route(TEST_QUEUE)) do |_env, message|
      raise "unexpected error" if message.payload["raise"]
      $responses << message.payload["message"]
    end
  end

  def setup
    @publisher_connection = get_new_connection
    @publisher = ElmerFudd::JsonPublisher.new(@publisher_connection, logger: NullLoger.new)
    @worker_connection = get_new_connection
    $responses = Queue.new
  end

  def teardown
    @publisher_connection.stop
    remove_queue TEST_QUEUE
  end

  def test_basic_cast
    @worker = TestWorker.new(@worker_connection, logger: NullLoger.new).
              tap(&:start)
    @publisher.cast TEST_QUEUE, message: "hello"

    Timeout.timeout(0.5) do
      assert "hello", $responses.pop
    end
  end

  def test_basic_cast_blocks_worker_if_unexpected_exception_occurs
    @worker = TestWorker.new(@worker_connection, logger: NullLoger.new).
              tap(&:start)
    @publisher.cast TEST_QUEUE, message: "hello", raise: true
    @publisher.cast TEST_QUEUE, message: "hello"

    Timeout.timeout(0.5) do
      loop { assert $responses.empty? }
    end rescue Timeout::Error
  end

  def test_workers_continues_if_concurency_greater_than_1
    @worker = TestWorker.new(@worker_connection, concurrency: 2,
                             logger: NullLoger.new).
              tap(&:start)
    @publisher.cast TEST_QUEUE, message: "hello", raise: true
    @publisher.cast TEST_QUEUE, message: "hello2"

    Timeout.timeout(0.5) do
      assert "hello2", $responses.pop
    end
  end

end
