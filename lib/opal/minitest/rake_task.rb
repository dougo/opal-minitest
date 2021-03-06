require 'rake'
require 'phantomjs'
require 'opal/minitest'
require 'opal/minitest/arg_processor'

module Opal
  module Minitest
    class RakeTask
      include Rake::DSL

      RUNNER_PATH = File.expand_path('../../../../vendor/runner.js', __FILE__)

      def initialize(args = {})
        args = defaults.merge(args)

        desc "Run tests through opal-minitest"
        task(args[:name]) do
          require 'rack'
          require 'webrick'
          require 'tilt/erb'

          server = fork {
            Rack::Server.start(
              app: Server.new(requires_glob: args[:requires_glob]),
              Port: args[:port],
              server: 'webrick',
              Logger: WEBrick::Log.new('/dev/null'),
              AccessLog: [])
          }

          system Phantomjs.path, RUNNER_PATH, "http://localhost:#{args[:port]}"

          Process.kill(:SIGINT, server)
          Process.wait
        end
      end

      private

      def defaults
        {
          name: 'default',
          port: 2838,
          requires_glob: 'test/{test_helper,**/*_test}.{rb,opal}'
        }
      end

      class Server < Opal::Server
        def initialize(args)
          super

          $omt_requires_glob = args.fetch(:requires_glob)
          $omt_minitest_opts = ArgProcessor.process_args(Shellwords.split(ENV['TESTOPTS'] || ''))

          $LOAD_PATH.each { |p| append_path(p) }
          append_path 'test'
          self.main = 'opal/minitest/loader'
        end
      end
    end
  end
end
