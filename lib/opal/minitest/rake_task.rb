require 'rake'
require 'opal/minitest'

module Opal
  module Minitest
    class RakeTask
      include Rake::DSL

      PORT = 2838
      RUNNER = File.expand_path('../../../../vendor/runner.js', __FILE__)

      def initialize(name = 'opal:minitest')
        desc "Run tests through opal-minitest"
        task(name) do
          require 'rack'
          require 'webrick'

          server = fork {
            Rack::Server.start(
              app: Server.new,
              Port: PORT,
              server: 'webrick',
              Logger: WEBrick::Log.new('/dev/null'),
              AccessLog: [])
          }

          system "phantomjs #{RUNNER} \"http://localhost:#{PORT}\""

          Process.kill(:SIGINT, server)
          Process.wait
        end
      end

      class Server < Opal::Server
        def initialize
          super

          $LOAD_PATH.each { |p| append_path(p) }
          append_path 'test'
          self.main = 'opal/minitest/loader'
          self.debug = false
        end
      end
    end
  end
end
