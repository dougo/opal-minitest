module Minitest
  ##
  # Represents anything "runnable", like Test, Spec, Benchmark, or
  # whatever you can dream up.
  #
  # Subclasses of this are automatically registered and available in
  # Runnable.runnables.

  class Runnable
    ##
    # Number of assertions executed in this run.

    attr_accessor :assertions

    ##
    # An assertion raised during the run, if any.

    attr_accessor :failures

    ##
    # Name of the run.

    def name
      @NAME
    end

    ##
    # Set the name of the run.

    def name= o
      @NAME = o
    end

    def self.inherited klass # :nodoc:
      self.runnables << klass
      super
    end

    ##
    # Returns all instance methods matching the pattern +re+.

    def self.methods_matching re
      public_instance_methods(true).grep(re).map(&:to_s)
    end

    def self.reset # :nodoc:
      @@runnables = []
    end

    reset

    ##
    # Responsible for running all runnable methods in a given class,
    # each in its own instance. Each instance is passed to the
    # reporter to record.

    def self.run reporter, options = {}
      filter = options[:filter] || '/./'
      filter = Regexp.new $1 if filter =~ /\/(.*)\//

      filtered_methods = self.runnable_methods.find_all { |m|
        filter === m || filter === "#{self}##{m}"
      }

      with_info_handler reporter do
        filtered_methods.each do |method_name|
          run_one_method self, method_name, reporter
        end
      end
    end

    def self.run_one_method klass, method_name, reporter
      reporter.record Minitest.run_one_method(klass, method_name)
    end

    def self.with_info_handler reporter, &block # :nodoc:
      handler = lambda do
        unless reporter.passed? then
          warn "Current results:"
          warn ""
          warn reporter.reporters.first
          warn ""
        end
      end

      on_signal "INFO", handler, &block
    end

    def self.on_signal name, action # :nodoc:
      # PORT: modified
      #supported = Signal.list[name]

      #old_trap = trap name do
      #  old_trap.call if old_trap.respond_to? :call
      #  action.call
      #end if supported

      #yield
    #ensure
      #trap name, old_trap if supported

      yield
    end

    ##
    # Each subclass of Runnable is responsible for overriding this
    # method to return all runnable methods. See #methods_matching.

    def self.runnable_methods
      raise NotImplementedError, "subclass responsibility"
    end

    ##
    # Returns all subclasses of Runnable.

    def self.runnables
      @@runnables
    end

    def marshal_dump # :nodoc:
      [self.name, self.failures, self.assertions]
    end

    def marshal_load ary # :nodoc:
      self.name, self.failures, self.assertions = ary
    end

    def failure # :nodoc:
      self.failures.first
    end

    def initialize name # :nodoc:
      self.name       = name
      self.failures   = []
      self.assertions = 0
    end

    ##
    # Runs a single method. Needs to return self.

    def run
      raise NotImplementedError, "subclass responsibility"
    end

    ##
    # Did this run pass?
    #
    # Note: skipped runs are not considered passing, but they don't
    # cause the process to exit non-zero.

    def passed?
      raise NotImplementedError, "subclass responsibility"
    end

    ##
    # Returns a single character string to print based on the result
    # of the run. Eg ".", "F", or "E".

    def result_code
      raise NotImplementedError, "subclass responsibility"
    end

    ##
    # Was this run skipped? See #passed? for more information.

    def skipped?
      raise NotImplementedError, "subclass responsibility"
    end
  end

  ##
  # Defines the API for Reporters. Subclass this and override whatever
  # you want. Go nuts.

  class AbstractReporter
    # PORT: unsupported
    #include Mutex_m

    ##
    # Starts reporting on the run.

    def start
    end

    ##
    # Record a result and output the Runnable#result_code. Stores the
    # result of the run if the run did not pass.

    def record result
    end

    ##
    # Outputs the summary of the run.

    def report
    end

    ##
    # Did this run pass?

    def passed?
      true
    end
  end

  class Reporter < AbstractReporter # :nodoc:
    ##
    # The IO used to report.

    attr_accessor :io

    ##
    # Command-line options for this run.

    attr_accessor :options

    def initialize io = $stdout, options = {} # :nodoc:
      super()
      self.io      = io
      self.options = options
    end
  end

  ##
  # A very simple reporter that prints the "dots" during the run.
  #
  # This is added to the top-level CompositeReporter at the start of
  # the run. If you want to change the output of minitest via a
  # plugin, pull this out of the composite and replace it with your
  # own.

  class ProgressReporter < Reporter
    def record result # :nodoc:
      io.print "%s#%s = %.2f s = " % [result.class, result.name, result.time] if
        options[:verbose]
      io.print result.result_code
      io.puts if options[:verbose]
    end
  end

  ##
  # A reporter that gathers statistics about a test run. Does not do
  # any IO because meant to be used as a parent class for a reporter
  # that does.
  #
  # If you want to create an entirely different type of output (eg,
  # CI, HTML, etc), this is the place to start.

  class StatisticsReporter < Reporter
    # :stopdoc:
    attr_accessor :assertions
    attr_accessor :count
    attr_accessor :results
    attr_accessor :start_time
    attr_accessor :total_time
    attr_accessor :failures
    attr_accessor :errors
    attr_accessor :skips
    # :startdoc:

    def initialize io = $stdout, options = {} # :nodoc:
      super

      self.assertions = 0
      self.count      = 0
      self.results    = []
      self.start_time = nil
      self.total_time = nil
      self.failures   = nil
      self.errors     = nil
      self.skips      = nil
    end

    def passed? # :nodoc:
      results.all?(&:skipped?)
    end

    def start # :nodoc:
      self.start_time = Time.now
    end

    def record result # :nodoc:
      self.count += 1
      self.assertions += result.assertions

      results << result if not result.passed? or result.skipped?
    end

    def report # :nodoc:
      aggregate = results.group_by { |r| r.failure.class }
      aggregate.default = [] # dumb. group_by should provide this

      self.total_time = Time.now - start_time
      self.failures   = aggregate[Assertion].size
      self.errors     = aggregate[UnexpectedError].size
      self.skips      = aggregate[Skip].size
    end
  end

  ##
  # A reporter that prints the header, summary, and failure details at
  # the end of the run.
  #
  # This is added to the top-level CompositeReporter at the start of
  # the run. If you want to change the output of minitest via a
  # plugin, pull this out of the composite and replace it with your
  # own.

  class SummaryReporter < StatisticsReporter
    # :stopdoc:
    attr_accessor :sync
    attr_accessor :old_sync
    # :startdoc:

    def start # :nodoc:
      super

      io.puts "Run options: #{options[:args]}"
      io.puts
      io.puts "# Running:"
      io.puts

      self.sync = io.respond_to? :"sync=" # stupid emacs
      self.old_sync, io.sync = io.sync, true if self.sync
    end

    def report # :nodoc:
      super

      # PORT: unsupported
      #io.sync = self.old_sync

      io.puts unless options[:verbose] # finish the dots
      io.puts
      io.puts statistics
      io.puts aggregated_results
      io.puts summary
    end

    def statistics # :nodoc:
      "Finished in %.6fs, %.4f runs/s, %.4f assertions/s." %
        [total_time, count / total_time, assertions / total_time]
    end

    def aggregated_results # :nodoc:
      filtered_results = results.dup
      filtered_results.reject!(&:skipped?) unless options[:verbose]

      filtered_results.each_with_index.map do |result, i|
        "\n%3d) %s" % [i+1, result]
      end.join("\n") + "\n"
    end

    alias to_s aggregated_results

    def summary # :nodoc:
      extra = ""

      extra = "\n\nYou have skipped tests. Run with --verbose for details." if
        results.any?(&:skipped?) unless options[:verbose] or ENV["MT_NO_SKIP_MSG"]

      "%d runs, %d assertions, %d failures, %d errors, %d skips%s" %
        [count, assertions, failures, errors, skips, extra]
    end
  end

  ##
  # Dispatch to multiple reporters as one.

  class CompositeReporter < AbstractReporter
    ##
    # The list of reporters to dispatch to.

    attr_accessor :reporters

    def initialize *reporters # :nodoc:
      super()
      self.reporters = reporters
    end

    ##
    # Add another reporter to the mix.

    def << reporter
      self.reporters << reporter
    end

    def passed? # :nodoc:
      self.reporters.all?(&:passed?)
    end

    def start # :nodoc:
      self.reporters.each(&:start)
    end

    def record result # :nodoc:
      self.reporters.each do |reporter|
        reporter.record result
      end
    end

    def report # :nodoc:
      self.reporters.each(&:report)
    end
  end

  ##
  # Represents run failures.

  class Assertion < Exception
    def error # :nodoc:
      self
    end

    ##
    # Where was this run before an assertion was raised?

    def location
      last_before_assertion = ""
      self.backtrace.reverse_each do |s|
        break if s =~ /in .(assert|refute|flunk|pass|fail|raise|must|wont)/
        last_before_assertion = s
      end
      last_before_assertion.sub(/:in .*$/, "")
    end

    def result_code # :nodoc:
      result_label[0, 1]
    end

    def result_label # :nodoc:
      "Failure"
    end

    # PORT: added
    def backtrace
      Minitest::filter_backtrace(super)
    end
  end

  ##
  # Assertion raised when skipping a run.

  class Skip < Assertion
    def result_label # :nodoc:
      "Skipped"
    end
  end

  ##
  # Assertion wrapping an unexpected error that was raised during a run.

  class UnexpectedError < Assertion
    attr_accessor :exception # :nodoc:

    def initialize exception # :nodoc:
      super
      self.exception = exception
    end

    def backtrace # :nodoc:
      self.exception.backtrace
    end

    def error # :nodoc:
      self.exception
    end

    def message # :nodoc:
      bt = Minitest::filter_backtrace(self.backtrace).join "\n    "
      "#{self.exception.class}: #{self.exception.message}\n    #{bt}"
    end

    def result_label # :nodoc:
      "Error"
    end
  end

  ##
  # Provides a simple set of guards that you can use in your tests
  # to skip execution if it is not applicable. These methods are
  # mixed into Test as both instance and class methods so you
  # can use them inside or outside of the test methods.
  #
  #   def test_something_for_mri
  #     skip "bug 1234"  if jruby?
  #     # ...
  #   end
  #
  #   if windows? then
  #     # ... lots of test methods ...
  #   end

  module Guard

    ##
    # Is this running on opal?
    # PORT: added

    def opal? platform = RUBY_PLATFORM
      "opal" == platform
    end

    ##
    # Is this running on jruby?

    def jruby? platform = RUBY_PLATFORM
      "java" == platform
    end

    ##
    # Is this running on maglev?

    def maglev? platform = defined?(RUBY_ENGINE) && RUBY_ENGINE
      "maglev" == platform
    end

    ##
    # Is this running on mri?

    def mri? platform = RUBY_DESCRIPTION
      /^ruby/ =~ platform
    end

    ##
    # Is this running on rubinius?

    def rubinius? platform = defined?(RUBY_ENGINE) && RUBY_ENGINE
      "rbx" == platform
    end

    ##
    # Is this running on windows?

    def windows? platform = RUBY_PLATFORM
      /mswin|mingw/ =~ platform
    end
  end

  class BacktraceFilter # :nodoc:
    def filter bt
      return ["No backtrace"] unless bt

      return bt.dup if $DEBUG

      new_bt = bt.take_while { |line| line !~ /lib\/minitest/ }
      new_bt = bt.select     { |line| line !~ /lib\/minitest/ } if new_bt.empty?
      new_bt = bt.dup                                           if new_bt.empty?

      new_bt
    end
  end
end
